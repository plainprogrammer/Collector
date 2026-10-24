# Compares two consolidated snapshots of a primary database, the old one a release made and the new one the code under
# test upgraded (spec 031 decision 5, Story 4). It reads them with SQLite directly, never through the application: for
# every table of the old database the table must exist and hold the same rows over the columns both have. A difference is
# a failure unless an expected change (decision 6) lists it.
require "digest"
require "sqlite3"

module Upgrade
  class Compare
    SEPARATOR = "\x1f".freeze # quote() never produces it at a value boundary: text is wrapped in quotes, numbers are digits
    SKIPPED = %w[schema_migrations ar_internal_metadata].freeze
    HINT = "A migration must not lose data: fix it, or list the change in script/upgrade/expected_changes.yml with the " \
      "migration's version and a reason that names the spec."

    Difference = Struct.new(:table, :column, :kind, :key, :detail, keyword_init: true) do
      def label = [ table, column ].compact.join(".")
      def to_s = "#{label}: #{detail}#{" (first key #{key})" if key}"
    end

    Report = Struct.new(:lines, :failures, :expected, :unmatched, keyword_init: true) do
      def ok? = failures.empty? && unmatched.empty?

      def to_lines
        lines + failures.map { "FAIL #{it}" } +
          expected.map { |entry, difference| "expected: #{difference.label} #{entry.kind} (#{entry.reason})" } +
          unmatched.map { "FAIL expected_changes.yml: #{[ it.table, it.column ].compact.join(".")} #{it.kind} (migration #{it.migration}) matched no difference; remove it or fix it" } +
          (failures.empty? ? [] : [ HINT ])
      end
    end

    class << self
      def quote_id(name) = %("#{name.gsub('"', '""')}")

      # The tables a comparison and the coverage rule look at: not SQLite's own, not schema_migrations or
      # ar_internal_metadata, and not a virtual (full-text) table or the shadow tables SQLite keeps for it.
      def tables(db)
        rows = db.execute("SELECT name, sql FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite\\_%' ESCAPE '\\' ORDER BY name")
        virtual = rows.select { |_name, sql| sql.to_s.start_with?("CREATE VIRTUAL TABLE") }.map(&:first)
        rows.map(&:first).reject { |name| SKIPPED.include?(name) || virtual.any? { |each| name == each || name.start_with?("#{each}_") } }
      end

      def count(db, table) = db.get_first_value("SELECT count(*) FROM #{quote_id(table)}")

      def columns(db, table) = db.execute("PRAGMA table_info(#{quote_id(table)})").map { it[1] }

      def primary_key(db, table)
        db.execute("PRAGMA table_info(#{quote_id(table)})").select { it[5].positive? }.sort_by { it[5] }.map { it[1] }
      end

      def integrity(db)
        db.execute("PRAGMA integrity_check").flatten.reject { it == "ok" }.map { "integrity_check: #{it}" } +
          db.execute("PRAGMA foreign_key_check").map { |table, rowid, parent, *| "foreign_key_check: #{table} row #{rowid} has no row in #{parent}" }
      end

      # The count and digest of decision 5: SHA-256 of the SHA-256 of each row, a row being its quote()d values joined.
      def digest(rows)
        rows.each_with_object(Digest::SHA256.new) { |row, total| total << Digest::SHA256.hexdigest(row.join(SEPARATOR)) << "\n" }.hexdigest
      end

      # What AC-2.3 says the seed left, read back from the old snapshot.
      def seed_problems(db)
        found = []
        found << "fewer than two accounts" if count(db, "accounts") < 2
        found << "a user without a password" if db.get_first_value("SELECT count(*) FROM users WHERE coalesce(password_digest, '') = ''").positive?
        found << "fewer than 2,000 lots" if count(db, "lots") < 2000
        found << "no account without lots" if db.get_first_value("SELECT count(*) FROM accounts WHERE id NOT IN (SELECT account_id FROM lots)").zero?
        found << "sign-up is not open" if db.get_first_value("SELECT count(*) FROM instance_settings WHERE sign_up_open = 1").zero?
        found << "fewer than two locations" if tables(db).include?("locations") && count(db, "locations") < 2
        found.map { "AC-2.3: the seed left #{it}" }
      end
    end

    def initialize(old_db, new_db, expected: [], optional: [], emptied: [])
      @old = old_db
      @new = new_db
      @expected = expected
      @optional = optional
      @emptied = emptied
    end

    def call
      (@expected + @optional).each { it.matched = false }
      new_tables = self.class.tables(@new)
      lines = []
      differences = []
      self.class.tables(@old).each do |table|
        found, line = compare_table(table, new_tables)
        lines << line
        differences.concat(found)
      end
      @emptied.each { |table| differences << not_emptied(table) if new_tables.include?(table) && self.class.count(@new, table).positive? }
      report(lines, differences)
    end

    private
      def compare_table(table, new_tables)
        old_count = self.class.count(@old, table)
        unless new_tables.include?(table)
          return [ [ difference(table, nil, :table_dropped, nil, "table dropped (it held #{old_count} rows)") ], line(table, old_count, "-", "dropped") ]
        end

        old_columns = self.class.columns(@old, table)
        new_columns = self.class.columns(@new, table)
        found = (old_columns - new_columns).map { difference(table, it, :column_dropped, nil, "column dropped") }
        common = (old_columns & new_columns).sort
        key = self.class.primary_key(@old, table)
        keyed = key.size == 1 && common.include?(key.first)
        order = keyed ? key : common
        old_rows = rows(@old, table, common, order)
        new_rows = rows(@new, table, common, order)
        same = old_rows.size == new_rows.size && self.class.digest(old_rows) == self.class.digest(new_rows)
        unless same
          found.concat(keyed ? keyed_differences(table, common, key.first, old_rows, new_rows) : positional_differences(table, common, old_rows, new_rows))
        end
        [ found, line(table, old_count, new_rows.size, same && found.empty? ? "same #{self.class.digest(old_rows)[0, 8]}" : "differs") ]
      end

      def rows(db, table, columns, order)
        return [] if columns.empty?

        select = columns.map { "quote(#{self.class.quote_id(it)})" }.join(", ")
        by = order.map { self.class.quote_id(it) }.join(", ")
        db.execute("SELECT #{select} FROM #{self.class.quote_id(table)} ORDER BY #{by}")
      end

      def keyed_differences(table, common, key, old_rows, new_rows)
        at = common.index(key)
        old_by = old_rows.to_h { [ it[at], it ] }
        new_by = new_rows.to_h { [ it[at], it ] }
        removed = old_by.keys - new_by.keys
        added = new_by.keys - old_by.keys
        shared = old_by.keys & new_by.keys
        found = []
        found << difference(table, nil, :rows_removed, "#{key} = #{removed.first}", "#{removed.size} rows removed") if removed.any?
        found << difference(table, nil, :rows_added, "#{key} = #{added.first}", "#{added.size} rows added") if added.any?
        common.each_with_index do |column, position|
          changed = shared.find { old_by[it][position] != new_by[it][position] }
          found << difference(table, column, :value_changed, "#{key} = #{changed}", "values rewritten") if changed
        end
        found
      end

      def positional_differences(table, common, old_rows, new_rows)
        position = (0...[ old_rows.size, new_rows.size ].max).find { old_rows[it] != new_rows[it] }
        return [] unless position

        old_row = old_rows[position]
        new_row = new_rows[position]
        where = "row #{position + 1} of the ordering by #{common.join(", ")}"
        return [ difference(table, nil, :rows_added, "#{where}: #{new_row.join(", ")}", "rows added") ] if old_row.nil?
        return [ difference(table, nil, :rows_removed, "#{where}: #{old_row.join(", ")}", "rows removed") ] if new_row.nil?

        common.each_index.select { old_row[it] != new_row[it] }
          .map { difference(table, common[it], :value_changed, "#{where}: #{old_row.join(", ")}", "values rewritten") }
      end

      def not_emptied(table)
        difference(table, nil, :not_emptied, nil, "#{self.class.count(@new, table)} rows after the restore, which ends every session and so empties this table (spec 031 decision 7)")
      end

      def difference(table, column, kind, key, detail) = Difference.new(table:, column:, kind:, key:, detail:)

      def line(table, old_count, new_count, state) = format("%-32s old %6s  new %6s  %s", table, old_count, new_count, state)

      def report(lines, differences)
        expected = []
        failures = []
        differences.each do |difference|
          entry = (@expected + @optional).find { matches?(it, difference) }
          if entry
            entry.matched = true
            expected << [ entry, difference ]
          else
            failures << difference
          end
        end
        Report.new(lines:, failures:, expected:, unmatched: @expected.reject(&:matched))
      end

      def matches?(entry, difference)
        return false unless entry.table == difference.table

        case entry.kind
        when "dropped" then entry.column ? (difference.kind == :column_dropped && difference.column == entry.column) : difference.kind == :table_dropped
        when "rewritten" then difference.kind == :value_changed && difference.column == entry.column
        when "rows_removed" then difference.kind == :rows_removed
        when "rows_added" then difference.kind == :rows_added
        else false
        end
      end
  end
end
