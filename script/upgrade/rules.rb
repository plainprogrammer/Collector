# The two yml files of the upgrade proof and the rules that read them (spec 031 decisions 5 and 6; formats in
# docs/specs/031-upgrade-from-previous-release/contracts/yaml-files.md).
require "yaml"
require_relative "compare"

module Upgrade
  class ExpectedChanges
    KINDS = %w[dropped rewritten rows_removed rows_added].freeze
    Entry = Struct.new(:table, :column, :kind, :migration, :reason, :matched, keyword_init: true)
    Loaded = Struct.new(:live, :retired, :errors, keyword_init: true)

    # The tables spec 030 requires `backup:restore` to empty: it ends every session, and the foreign keys cascade. Spec 031
    # 1.1.2 (decision 7, FR-4, AC-6.2) names them; expected_changes_spec checks the list against the schema's `on_delete: :cascade` keys.
    RESTORE_ENDS_SESSIONS = %w[sessions bulk_removals bulk_selections bulk_selection_marks].freeze

    # Not a migration's change, so not in expected_changes.yml: the allowance of the backup leg only (plan P4).
    def self.restore_effects
      RESTORE_ENDS_SESSIONS.map do |table|
        Entry.new(table:, kind: "rows_removed",
          reason: "backup:restore ends every session, which cascades to the bulk removals and selections (spec 030, docs/backup-restore.md)")
      end
    end

    # An entry whose migration the previous release has is retired (ignored, never a failure); one whose migration is
    # not a file of the code under test is an error, so a typo can't excuse another migration's difference.
    def self.load(path, previous_versions:, current_versions:)
      data = YAML.safe_load_file(path, permitted_classes: [], aliases: false)
      data = {} if data.nil?
      return Loaded.new(live: [], retired: [], errors: [ "expected_changes.yml is not a mapping with a `changes` list" ]) unless data.is_a?(Hash)

      extra = data.keys - [ "changes" ]
      errors = extra.any? ? [ "expected_changes.yml has an unknown key: #{extra.join(", ")}" ] : []
      live = []
      retired = []
      Array(data["changes"]).each_with_index do |raw, index|
        entry, problems = build(raw, index + 1, current_versions)
        errors.concat(problems)
        (previous_versions.include?(entry.migration) ? retired : live) << entry if entry
      end
      Loaded.new(live:, retired:, errors:)
    end

    def self.build(raw, position, current_versions)
      where = "expected_changes.yml entry #{position}"
      return [ nil, [ "#{where} is not a mapping" ] ] unless raw.is_a?(Hash)

      problems = %w[table kind migration reason].select { raw[it].to_s.strip.empty? }.map { "#{where} has no #{it}" }
      problems << "#{where}: kind #{raw["kind"].inspect} is none of #{KINDS.join(", ")}" if raw["kind"] && !KINDS.include?(raw["kind"])
      problems << "#{where}: a rewritten change names its column" if raw["kind"] == "rewritten" && raw["column"].to_s.empty?
      migration = raw["migration"].to_s
      problems << "#{where} names migration #{migration}, which is not a file in db/migrate/" unless migration.empty? || current_versions.include?(migration)
      return [ nil, problems ] if problems.any?

      [ Entry.new(table: raw["table"], column: raw["column"]&.to_s, kind: raw["kind"], migration:, reason: raw["reason"]), [] ]
    end
    private_class_method :build
  end

  class SeedExceptions
    Entry = Struct.new(:table, :reason, keyword_init: true)
    Result = Struct.new(:entries, :errors)

    def self.load(path, key)
      data = YAML.safe_load_file(path, permitted_classes: [], aliases: false) || {}
      errors = []
      entries = Array(data[key.to_s]).each_with_index.filter_map do |item, index|
        if item.is_a?(Hash) && !item["table"].to_s.empty? && !item["reason"].to_s.empty?
          Entry.new(table: item["table"], reason: item["reason"])
        else
          errors << "seed_exceptions.yml #{key}: entry #{index + 1} needs a table and a reason"
          nil
        end
      end
      Result.new(entries, errors)
    end

    # The coverage rule: every table holds a row after a seed ran, except the listed ones. Returns the problems (each a
    # failure of the run) and the notes to print (every used exception). `only` limits the tables looked at (the suite's
    # test database also holds Solid Queue's).
    def self.coverage(db, entries, label:, seed:, only: nil)
      tables = Compare.tables(db)
      tables &= only if only
      excepted = entries.map(&:table)
      empty = tables.select { Compare.count(db, it).zero? }
      problems = (empty - excepted).map do
        "table #{it} has no row after #{seed}; the seed must fill it (script/upgrade/seed_exceptions.yml lists the tables that can't be filled, with a reason)"
      end
      problems += (excepted - tables).map { "script/upgrade/seed_exceptions.yml lists #{it} for #{label}, which has no such table" }
      notes = (empty & excepted).map { |table| "seed exception: #{table} (#{entries.find { it.table == table }.reason})" }
      [ problems, notes ]
    end
  end
end
