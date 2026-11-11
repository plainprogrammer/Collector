# Reads a version 4 file's proxies, one row at a time, as `CollectionImport` reads its lots (spec 068 decision 18): a problem under
# `/proxies/N` is a problem row of that proxy and never a refusal of the file; a `proxies` that isn't a list is refused with the
# header's problems. Included by `CollectionImport`, whose private helpers it shares (`entries_for`, `registered?`, `problem`,
# `field_reason`, `file_deck_formats`, `zone_name`); its constants are named in full (`CollectionImport::Problem`) because the
# compact module name leaves `CollectionImport` out of the lexical scope.
#
# The rules, each with its home: the schema's keywords, `duplicate_proxy` and `unknown_location` are the format's
# (`ExportFormat::Rules`); `unknown_type`, `not_in_catalog`, `finish_not_listed` and `unknown_zone` are the reader's, judged in
# that order for a row with no problem of the format. A proxy with no finish is never a problem (decision 2), and the reader
# never compares a proxy's collectible type with its deck's (decision 19).
# @see file:data-portability.md
module CollectionImport::ProxyRows
  PROXY_ROW = %r{\A/proxies/(\d+)(?:/(.+))?\z}
  DUPLICATE_PROXY_OF = "Same deck, zone, card and finish as proxy %d".freeze
  DUPLICATE_PROXY = "Same deck, zone, card and finish as an earlier proxy".freeze

  # One element of the file's proxies, numbered from 1. +identity+ is nil when it can't be read; +place+ is "Deck › Zone" as the
  # file spells the deck and the zone's registered name (its key when the format has none), nil when either isn't text.
  ProxyRow = Data.define(:number, :proxy, :identity, :problems, :place) do
    # Whether the row can't be applied.
    def problem? = problems.any?

    # The quantity the file gives.
    def quantity = proxy.is_a?(Hash) ? proxy["quantity"] : nil

    # The finish the file gives, when it is text.
    def finish = (proxy["finish"] if proxy.is_a?(Hash) && proxy["finish"].is_a?(String))

    # The card's name as the file writes it, when it is text.
    def name = text(entry["name"])

    # What the file says the row is, for a list (`import_proxy_line`'s keywords).
    def described = { set_code: text(entry["set_code"]), collector_number: text(entry["collector_number"]), language: text(entry["language"]), finish:, place: }

    # The file's entry object, or an empty one when it isn't.
    def entry = proxy.is_a?(Hash) && proxy["entry"].is_a?(Hash) ? proxy["entry"] : {}

    private
      def text(value) = (value if value.is_a?(String))
  end

  private
    def read_proxy_rows
      proxies = @data["proxies"]
      failed = @problems.reject { |problem| %w[duplicate_proxy unknown_location].include?(problem.rule) }.to_set(&:at)
      found = Hash.new { |hash, index| hash[index] = [] }
      @problems.each { |problem| (match = PROXY_ROW.match(problem.at)) && found[match[1].to_i] << problem }
      identities = proxies.each_with_index.map do |proxy, index|
        ExportFormat::Rules.proxy_identity(proxy) if ExportFormat::Rules.proxy_identity_readable?(proxy, "/proxies/#{index}", failed)
      end
      first = {}
      identities.each_with_index { |identity, index| first[identity] ||= index + 1 if identity }
      resolved = proxy_resolution_problems(proxies.each_with_index.reject { |_proxy, index| found.key?(index) })
      proxies.each_with_index.map do |proxy, index|
        problems = found.fetch(index, []).map { |item| describe_proxy_problem(item, first[identities[index]], proxy) } + resolved.fetch(index, [])
        ProxyRow.new(number: index + 1, proxy:, identity: identities[index], problems:, place: proxy_place_label(proxy))
      end
    end

    def proxy_place_label(proxy)
      return unless proxy.is_a?(Hash) && proxy["deck"].is_a?(String) && proxy["zone"].is_a?(String)

      Location::Placement.label(zone_name({ "deck" => proxy["deck"], "zone" => proxy["zone"] }) || proxy["zone"], proxy["deck"])
    end

    def describe_proxy_problem(item, earlier, proxy)
      case item.rule
      when "duplicate_proxy" then CollectionImport::Problem.new(rule: item.rule, at: item.at, reason: format(DUPLICATE_PROXY_OF, earlier), summary: DUPLICATE_PROXY)
      when "unknown_location"
        CollectionImport::Problem.new(rule: item.rule, at: item.at, reason: "Its deck “#{proxy["deck"]}” isn't one of the file's decks.", summary: "Its deck isn't one of the file's decks.")
      else
        field = PROXY_ROW.match(item.at)[2]&.tr("/", ".")
        reason = field ? field_reason(item.rule, field) : "This row isn't a proxy"
        CollectionImport::Problem.new(rule: item.rule, at: item.at, reason:, summary: reason)
      end
    end

    # The type, then the entry, then the finish (a non-null one the entry doesn't list); then, for a row with none of those, the
    # zone its deck's format lacks. Also remembers the entry each good row resolved to, for applying.
    def proxy_resolution_problems(candidates)
      found = {}
      candidates.group_by { |proxy, _index| proxy["entry"]["collectible_type"] }.each do |type, group|
        unless registered?(type)
          group.each { |_proxy, index| found[index] = [ problem("unknown_type", "/proxies/#{index}/entry/collectible_type", "This instance doesn't collect #{type}") ] }
          next
        end

        vocabulary = Catalog.collecting_for(type)
        entries = entries_for(type, group.map { |proxy, _index| proxy["entry"]["source_id"] })
        group.each do |proxy, index|
          entry = entries[proxy["entry"]["source_id"]]
          @proxy_entry_ids[index + 1] = entry&.id
          list = proxy_entry_problems(proxy, index, entry, vocabulary)
          zone = proxy_zone_problem(proxy, index) if list.empty?
          list << zone if zone
          found[index] = list if list.any?
        end
      end
      found
    end

    def proxy_entry_problems(proxy, index, entry, vocabulary)
      list = []
      list << problem("not_in_catalog", "/proxies/#{index}/entry/source_id", "Not in this instance's catalog") unless entry
      if entry && proxy["finish"] && vocabulary.finishes_for(entry).exclude?(proxy["finish"])
        list << problem("finish_not_listed", "/proxies/#{index}/finish", "This printing doesn't come in #{proxy["finish"]}")
      end
      list
    end

    # A proxy in a zone its deck's format lacks: the deck is listed (else it is `unknown_location`, a rule of the format) and
    # registered (else the file was refused), so only the zone key can be wrong; a resolvable check (spec 062 AC-6.11).
    def proxy_zone_problem(proxy, index)
      pair = file_deck_formats[Location::Name.key(Location::Name.normalise(proxy["deck"]))]
      zones = Catalog::Formats.zones_for(*pair) if pair
      return unless zones && zones.none? { |zone| zone.key == proxy["zone"] }

      CollectionImport::Problem.new(rule: "unknown_zone", at: "/proxies/#{index}/zone", summary: "Its deck has no such zone in its format.",
        reason: "The deck “#{proxy["deck"]}” has no zone “#{proxy["zone"]}” in its format.")
    end
end
