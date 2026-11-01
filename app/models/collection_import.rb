# An export file read against one account's collection and this instance's catalog (spec 025; spec 029 reads version 2;
# spec 032 reads version 3, whose lots say where they are): either a refusal of
# the whole file (decision 10), or each row's problems and what applying the file would do (decisions 1, 2, 4, 9, 11).
# It writes nothing. Collectible-agnostic: a type's entries and vocabulary are reached through the catalog registry.
class CollectionImport
  MAX_BYTES = 32_000_000
  LIST_LIMIT = 100
  BATCH_SIZE = 1_000
  ROW = %r{\A/lots/(\d+)(?:/(.+))?\z}
  LOT_COLUMNS = [ "lots.id", "catalog_entries.collectible_type", "catalog_entries.external_key", "lots.finish", "lots.condition",
    "lots.price_paid_cents", "lots.quantity", "lots.created_at", "lots.updated_at", "catalog_entries.name",
    "catalog_sets.code", "catalog_entries.number", "catalog_entries.language", "locations.name", "locations.name_key" ].freeze

  NO_FILE = "Choose an export file to preview.".freeze
  TOO_LARGE = "This file is larger than 32 MB, so it can't be an export Collector reads.".freeze
  NOT_JSON = "This file isn't a Collector export: it isn't readable JSON.".freeze
  NOT_AN_EXPORT = "This file isn't a Collector export.".freeze
  NO_VERSION = "This file doesn't say which version of the export format it follows.".freeze
  DUPLICATE_OF = "Same card, finish, condition and price as row %d".freeze
  DUPLICATE = "Same card, finish, condition and price as an earlier row".freeze
  # Version 3 adds the location to the identity, and the reason names it: two rows of "Box" and "box" are one lot (spec 032 AC-9.5).
  DUPLICATE_OF_PLACED = "Same card, finish, condition, price and location as row %d".freeze
  DUPLICATE_PLACED = "Same card, finish, condition, price and location as an earlier row".freeze
  # The largest price in cents the lots table records (a SQLite integer is 64 bits); spec 028 1.3.4.
  MAX_PRICE_CENTS = (2**63) - 1
  PRICE_TOO_LARGE = "price_paid is too large to record".freeze

  Refusal = Data.define(:rule, :at, :reason)
  # One reason a row can't be applied; +summary+ is the reason without what belongs to that row alone.
  Problem = Data.define(:rule, :at, :reason, :summary)
  Tally = Data.define(:lots, :copies, :copies_after) do
    def initialize(lots:, copies:, copies_after: nil) = super
  end

  # A lot of the collection, as the file would write it, with its id for applying (#40).
  # +location+ is the name of the location it is in, nil when unplaced; the sixth identity value is that location's key.
  HeldLot = Data.define(:id, :identity, :quantity, :added_at, :changed_at, :name, :set_code, :collector_number, :language,
    :created_exact, :updated_exact, :location) do
    def described
      { set_code:, collector_number:, language:, finish: identity[2], condition: identity[3], price_paid: identity[4], location: }
    end
  end

  # One element of the file's lots, numbered from 1. +identity+ is nil when it can't be read (decision 1).
  # +place+ is the file's spelling of a version 3 lot's location, nil for a lot in none or a file that has no places.
  Row = Data.define(:number, :lot, :identity, :problems, :place) do
    def problem? = problems.any?

    def quantity = lot["quantity"]

    def same_as?(held) = quantity == held.quantity && lot["added_at"] == held.added_at && lot["changed_at"] == held.changed_at

    def name = text(entry["name"])

    # What the file says the row is, using only the values it gives as strings (decision 9).
    def described
      { set_code: text(entry["set_code"]), collector_number: text(entry["collector_number"]), language: text(entry["language"]),
        finish: field("finish"), condition: field("condition"), price_paid: field("price_paid"), location: place }
    end

    def entry = lot.is_a?(Hash) && lot["entry"].is_a?(Hash) ? lot["entry"] : {}

    private
      def field(name) = lot.is_a?(Hash) ? text(lot[name]) : nil

      def text(value) = (value if value.is_a?(String))
  end

  attr_reader :refusal, :rows

  # +file+ is the upload: anything that answers #read and #size. Anything else is no file.
  def initialize(account:, file:)
    @account = account
    @entry_ids = {}
    @refusal = read(file)
    @rows = refused? ? [] : read_rows
  end

  def refused? = !refusal.nil?

  # Whether the file says where its lots are (version 3); the page says so when it doesn't (spec 032 AC-10.4).
  def places? = @version >= 3

  # The catalog entry a row that isn't a problem row resolved to (for applying, spec 028).
  def entry_id(row) = @entry_ids.fetch(row.number)

  # What applying would do to the collection as it was when this was first asked (the preview's view, spec 028).
  def plan = @plan ||= Plan.new(outcomes, view_change, locations)

  # The same, against the collection as it is now: one read of the lots, of the locations and of the user, no parsing
  # (spec 028 FR-2, spec 029 decision 11). It replaces the memoized plan, outcomes and locations, so that the page an apply
  # renders afterwards shows what the apply decided.
  def replan
    user.reload
    @removed_lots = nil # memoized from the outcomes below by #removed_lots
    @locations = nil
    @outcomes = outcomes_for(held_lots)
    @plan = Plan.new(@outcomes, view_change, locations)
  end

  # What applying would do with the collector's locations: nothing counted for a version 1 file (spec 029 decision 10).
  def locations = @locations ||= Locations.new(held_locations, @version >= 2 ? file_location_names : nil)

  def applicable? = !refused? && problem_rows.empty?

  def exported_at = Time.iso8601(@data["exported_at"])

  def currency = @data["currency"]

  def problem_rows = @problem_rows ||= rows.select(&:problem?)

  def listed_problem_rows = problem_rows.first(LIST_LIMIT)

  def more_problem_rows = problem_rows.size - listed_problem_rows.size

  # How many problem rows have each kind of problem, in the order the kinds first appear.
  def problem_counts = problem_rows.flat_map { |row| row.problems.map(&:summary).uniq }.tally

  def added = outcomes.fetch(:added)
  def changed = outcomes.fetch(:changed)
  def unchanged = outcomes.fetch(:unchanged)
  def held = outcomes.fetch(:held)
  def removed = outcomes.fetch(:removed)

  # The first removed lots, by name, then set code, collector number, language and identity (decision 11).
  def removed_lots
    @removed_lots ||= outcomes.fetch(:removed_lots)
      .sort_by { |lot| [ lot.name, lot.set_code, lot.collector_number, lot.language, lot.identity.map(&:to_s) ] }.first(LIST_LIMIT)
  end

  def more_removed_lots = removed.lots - removed_lots.size

  # What applying would do with a row: :added, :changed or :unchanged, or nil for a problem row (FR-1; for #40).
  def row_outcome(row) = outcomes.fetch(:row_outcomes)[row.number]

  # The held lot a row that isn't a problem row matches, or nil (for #40).
  def held_lot_for(row) = outcomes.fetch(:matched_lots)[row.identity]

  # Every lot applying would remove, and every lot a problem row holds back, in no order (for #40).
  def all_removed_lots = outcomes.fetch(:removed_lots)
  def lots_held_by_problem_rows = outcomes.fetch(:held_by_problem_rows)

  # The view applying would choose, when it is one the instance knows and isn't the collector's (decision 4).
  def view_change
    view = @data.dig("profile", "collection_view")
    view if User::COLLECTION_VIEWS.include?(view) && view != user.collection_view
  end

  def other_name = differing("name")

  def other_email_address = differing("email_address")

  def unloaded_catalog_titles
    Catalog.unloaded_titles(rows.filter_map { |row| row.entry["collectible_type"] }.grep(String).uniq)
  end

  private
    def user = @account.user

    def differing(field)
      value = @data.dig("profile", field)
      value unless value == user.public_send(field)
    end

    def refuse(rule, at, reason) = Refusal.new(rule:, at:, reason:)

    def read(file)
      return refuse("no_file", "", NO_FILE) unless file.respond_to?(:read) && file.respond_to?(:size) && file.size.positive?
      return refuse("too_large", "", TOO_LARGE) if file.size > MAX_BYTES

      @data, problem = ExportFormat::Rules.parse(file.read)
      return refuse(problem.rule, "", NOT_JSON) if problem

      header_refusal || currency_refusal
    end

    # Decision 10's checks in order: an export, its version (read before the schema), then the schema and the time
    # rule outside the rows.
    def header_refusal
      return refuse("type", "", NOT_AN_EXPORT) unless @data.is_a?(Hash)
      return refuse("required", "/format", NOT_AN_EXPORT) unless @data.key?("format")
      return refuse("const", "/format", NOT_AN_EXPORT) unless @data["format"] == ExportFormat::Rules::FORMAT
      return refuse("required", "/format_version", NO_VERSION) unless @data.key?("format_version")

      @version = ExportFormat::Rules.whole_number(@data["format_version"])
      return refuse("const", "/format_version", NO_VERSION) unless @version&.positive?
      return refuse("newer_version", "/format_version", newer(@version)) if @version > ExportFormat::Rules::VERSION

      @problems = ExportFormat::Rules.problems_in(@data)
      outside = @problems.reject { |problem| ROW.match?(problem.at) }
      first = outside.min_by { |problem| [ position(problem.at), outside.index(problem) ] }
      return refuse(first.rule, first.at, "This file isn't a well-formed export: #{field_reason(first.rule, field_name(first.at))}.") if first

      long_location
    end

    # A well-formed name whose NFC form is over 60 code points (U+0344 decomposes to two) can't be stored, so the file is
    # refused as a whole (spec 029 decision 9, an accepted limit).
    def long_location
      return unless @version >= 2

      index = @data["locations"].index { |location| Location::Name.normalise(location["name"]).length > Location::Name::MAX_LENGTH }
      index && refuse("maxLength", "/locations/#{index}/name", "This file isn't a well-formed export: #{field_reason("maxLength", "locations.#{index}.name")}.")
    end

    def currency_refusal
      code = Rails.configuration.x.currency.code
      return if @data["currency"] == code

      refuse("other_currency", "/currency", "This file's prices are in #{@data["currency"]}. This instance uses #{code}.")
    end

    def newer(version)
      "This file was written by a newer version of Collector (format version #{version}). " \
        "This instance reads version #{ExportFormat::Rules::VERSION}."
    end

    # Where a header pointer's field sits in the file; a missing field after all those present.
    def position(at) = @data.keys.index(at.split("/")[1]) || @data.size

    def field_name(pointer) = pointer.delete_prefix("/").tr("/", ".")

    def field_reason(rule, field)
      case rule
      when "required" then "#{field} is missing"
      when "not_a_time" then "#{field} isn't a real moment"
      when "duplicate_location" then "#{field} has the same name as an earlier location, ignoring case"
      else "#{field} isn't valid"
      end
    end

    def file_location_names = @data["locations"].map { |location| Location::Name.normalise(location["name"]) }

    # The account's locations, in one statement (at most 500 rows).
    def held_locations
      @account.locations.pluck(:id, :name, :name_key).map { |id, name, key| Locations::Held.new(id:, name:, key:) }
    end

    def read_rows
      lots = @data["lots"]
      # A duplicate is found by its identity, so its own pointer doesn't make that identity unreadable.
      failed = @problems.reject { |problem| %w[duplicate_lot unknown_location].include?(problem.rule) }.to_set(&:at)
      found = Hash.new { |hash, index| hash[index] = [] }
      @problems.each { |problem| (match = ROW.match(problem.at)) && found[match[1].to_i] << problem }
      identities = lots.each_with_index.map do |lot, index|
        ExportFormat::Rules.identity(lot, @version) if ExportFormat::Rules.identity_readable?(lot, "/lots/#{index}", failed)
      end
      first_row = {}
      identities.each_with_index { |identity, index| first_row[identity] ||= index + 1 if identity }
      candidates = lots.each_with_index.reject { |_lot, index| found.key?(index) }
      resolved = resolution_problems(candidates)
      candidates.each do |lot, index|
        next unless price_too_large?(lot)

        resolved[index] = resolved.fetch(index, []) + [ problem("price_too_large", "/lots/#{index}/price_paid", PRICE_TOO_LARGE) ]
      end
      lots.each_with_index.map do |lot, index|
        problems = found.fetch(index, []).map { |problem| describe(problem, first_row[identities[index]], lot) } + resolved.fetch(index, [])
        place = lot["location"] if @version >= 3 && lot.is_a?(Hash) && lot["location"].is_a?(String)
        Row.new(number: index + 1, lot:, identity: identities[index], problems:, place:)
      end
    end

    def describe(problem, earlier, lot)
      if problem.rule == "duplicate_lot"
        of, summary = @version >= 3 ? [ DUPLICATE_OF_PLACED, DUPLICATE_PLACED ] : [ DUPLICATE_OF, DUPLICATE ]
        return Problem.new(rule: problem.rule, at: problem.at, reason: format(of, earlier), summary:)
      end
      if problem.rule == "unknown_location"
        return Problem.new(rule: problem.rule, at: problem.at, reason: "Its location “#{lot["location"]}” isn't one of the file's locations.",
          summary: "Its location isn't one of the file's locations.")
      end

      field = ROW.match(problem.at)[2]&.tr("/", ".")
      reason = case problem.rule
      when "changed_before_added" then "changed_at is earlier than added_at"
      else field ? field_reason(problem.rule, field) : "This row isn't a lot"
      end
      Problem.new(rule: problem.rule, at: problem.at, reason:, summary: reason)
    end

    # Decision 9's catalog checks for well-formed rows: the type, then the entry, then its finish and the condition.
    def resolution_problems(candidates)
      candidates.group_by { |lot, _index| lot["entry"]["collectible_type"] }.each_with_object({}) do |(type, group), found|
        unless registered?(type)
          group.each { |_lot, index| found[index] = [ problem("unknown_type", "/lots/#{index}/entry/collectible_type", "This instance doesn't collect #{type}") ] }
          next
        end

        vocabulary = Catalog.collecting_for(type)
        entries = entries_for(type, group.map { |lot, _index| lot["entry"]["source_id"] })
        group.each do |lot, index|
          @entry_ids[index + 1] = entries[lot["entry"]["source_id"]]&.id
          list = entry_problems(lot, index, entries[lot["entry"]["source_id"]], vocabulary)
          found[index] = list if list.any?
        end
      end
    end

    def entry_problems(lot, index, entry, vocabulary)
      list = []
      list << problem("not_in_catalog", "/lots/#{index}/entry/source_id", "Not in this instance's catalog") unless entry
      if entry && lot["finish"] && vocabulary.finishes_for(entry).exclude?(lot["finish"])
        list << problem("finish_not_listed", "/lots/#{index}/finish", "This printing doesn't come in #{lot["finish"]}")
      end
      if lot["condition"] && vocabulary.conditions.exclude?(lot["condition"])
        list << problem("condition_unknown", "/lots/#{index}/condition", "#{lot["condition"]} isn't a condition this instance knows")
      end
      list
    end

    def problem(rule, at, reason) = Problem.new(rule:, at:, reason:, summary: reason)

    # A well-formed price is digits, a point and two decimals; in cents it must fit the column (spec 028 1.3.4).
    def price_too_large?(lot) = lot["price_paid"].is_a?(String) && lot["price_paid"].delete(".").to_i > MAX_PRICE_CENTS

    def registered?(type) = Catalog.collecting.key?(type) && Catalog.sources.key?(type)

    # The type's entries with these source ids, retired or not, with what their finishes need loaded (FR-4).
    def entries_for(type, source_ids)
      source_ids.uniq.each_slice(BATCH_SIZE).flat_map do |slice|
        Catalog::Entry.preload_extensions(Catalog::Entry.where(collectible_type: type, external_key: slice).to_a)
      end.index_by(&:external_key)
    end

    # The collection's lots, as the file would write them, read in one statement.
    def held_lots
      @account.lots.joins(entry: :set).left_joins(:location).pluck(*LOT_COLUMNS).map do |id, type, source_id, finish, condition, cents, quantity, added, changed, name, set_code, number, language, place, place_key|
        HeldLot.new(id:, identity: [ type, source_id, finish, condition, cents && format("%.2f", cents / 100r), place_key ], quantity:,
          added_at: added.getutc.iso8601, changed_at: changed.getutc.iso8601, name:, set_code:, collector_number: number, language:,
          created_exact: added.getutc.iso8601(6), updated_exact: changed.getutc.iso8601(6), location: place)
      end
    end

    # Decision 1: each row that isn't a problem row is added, changed or unchanged; each held lot is matched by such a
    # row, else held by a problem row that names it, else removed.
    def outcomes = @outcomes ||= outcomes_for(held_lots)

    def outcomes_for(held_list)
      held = held_list.index_by(&:identity)
      good = rows.reject(&:problem?)
      matched = good.select { |row| held.key?(row.identity) }.index_by(&:identity)
      changed, unchanged = matched.values.partition { |row| !row.same_as?(held[row.identity]) }
      named = problem_rows.filter_map(&:identity).to_set
      kept, removed = held.values.reject { |lot| matched.key?(lot.identity) }.partition { |lot| named.include?(lot.identity) }
      added = good.reject { |row| held.key?(row.identity) }
      row_outcomes = [ [ added, :added ], [ changed, :changed ], [ unchanged, :unchanged ] ]
        .flat_map { |list, outcome| list.map { |row| [ row.number, outcome ] } }.to_h
      { added: tally(added), unchanged: tally(unchanged),
        changed: Tally.new(lots: changed.size, copies: changed.sum { |row| held[row.identity].quantity },
                           copies_after: changed.sum { |row| row.quantity.to_i }),
        held: tally(kept), removed: tally(removed), row_outcomes:, held_by_problem_rows: kept, removed_lots: removed,
        matched_lots: matched.transform_values { |row| held[row.identity] },
        added_rows: added, changed_rows: changed }
    end

    def tally(items) = Tally.new(lots: items.size, copies: items.sum { |item| item.quantity.to_i })
end
