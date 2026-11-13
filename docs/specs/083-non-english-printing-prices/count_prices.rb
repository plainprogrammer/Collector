# Counts the prices Scryfall's bulk files carry for the printings of each language (research 083, issue #361).
#
# Usage: ruby count_prices.rb ALL_CARDS.jsonl.gz DEFAULT_CARDS.jsonl.gz > counts.md
#
# Reads both gzip JSON Lines files as streams, line by line, the way MTG::Scryfall::Source#each_entry reads them, and
# prints Markdown tables. Standard library only: it loads nothing from the app, writes nothing but standard output and
# keeps in memory only the few fields it compares. The population is the catalog's: paper printings, by the test of
# MTG::Scryfall::Mapper.paper? (repeated here, so the script runs without the app).
require "json"
require "set"
require "zlib"

class PriceCounts
  PRICE_KEYS = %w[usd usd_foil usd_etched eur eur_foil eur_etched tix].freeze
  # The price that goes with each finish, per currency: the price data design's six series.
  FINISH_KEYS = {
    "nonfoil" => { "USD" => "usd", "EUR" => "eur" },
    "foil" => { "USD" => "usd_foil", "EUR" => "eur_foil" },
    "etched" => { "USD" => "usd_etched", "EUR" => "eur_etched" }
  }.freeze
  OUTCOMES = %i[both_empty equal different english_only other_only].freeze
  EXAMPLES = 10
  OTHER_EXAMPLES = 3

  # A non-English paper printing, kept until every English one has been read.
  Other = Struct.new(:lang, :set, :number, :name, :finishes, :prices, :tcgplayer_id, :cardmarket_id, :id, :oracle_id)
  English = Struct.new(:prices, :tcgplayer_id, :cardmarket_id, :finishes, :oracle_id)

  def initialize(all_path, default_path)
    @all_path = all_path
    @default_path = default_path
    @languages = Hash.new { |hash, key| hash[key] = Hash.new(0) }
    @keys_present = Hash.new { |hash, key| hash[key] = Hash.new(0) }
    @coverage = Hash.new { |hash, key| hash[key] = Hash.new(0) }
    @english = {}
    @english_sets = Set.new
    @english_not_paper = Set.new
    @others = []
    @default_prices = {}
    @default_ids = Set.new
    @default_languages = Hash.new { |hash, key| hash[key] = Hash.new(0) }
    @files = Hash.new(0)
  end

  def run
    read(@default_path) { |card| default_card(card) }
    read(@all_path) { |card| all_card(card) }
    report
  end

  private
    def read(path)
      File.open(path, "rb") do |file|
        Zlib::GzipReader.wrap(file) do |gzip|
          gzip.each_line do |line|
            next if line.strip.empty?

            @files[File.basename(path)] += 1
            yield JSON.parse(line)
          end
        end
      end
    end

    def paper?(card) = !card["digital"] && Array(card["games"]).include?("paper")

    def prices(card) = card["prices"].is_a?(Hash) ? card["prices"] : {}

    def default_card(card)
      @default_prices[card.fetch("id")] = prices(card)
      @default_ids << card.fetch("id")
      counts = @default_languages[card.fetch("lang")]
      counts[:objects] += 1
      return unless paper?(card)

      counts[:paper] += 1
      counts[:paper_priced] += 1 if PRICE_KEYS.any? { |key| prices(card)[key] }
    end

    def all_card(card)
      lang = card.fetch("lang")
      compare_with_default(card)
      count_language("all", lang, card)
      @english_not_paper << [ card.fetch("set"), card.fetch("collector_number") ] if lang == "en" && !paper?(card)
      return unless paper?(card)

      count_language("paper", lang, card)
      count_coverage(lang, "all", card)
      keep_for_pairing(lang, card)
    end

    def compare_with_default(card)
      default = @default_prices.delete(card.fetch("id"))
      return unless default

      @files[:in_both] += 1
      differing = PRICE_KEYS.select { |key| default[key] != prices(card)[key] }
      @files[:identical] += 1 if differing.empty?
      differing.each { |key| @files[:"differs_#{key}"] += 1 }
    end

    def count_language(population, lang, card)
      counts = @languages[[ population, lang ]]
      counts[:objects] += 1
      counts[:with_prices] += 1 if card["prices"].is_a?(Hash)
      counts[:all_empty] += 1 if PRICE_KEYS.none? { |key| prices(card)[key] }
      counts[:tcgplayer_id] += 1 if card["tcgplayer_id"]
      counts[:cardmarket_id] += 1 if card["cardmarket_id"]
      counts[:tix] += 1 if prices(card)["tix"]
      prices(card).each_key { |key| @keys_present[population][key] += 1 }
    end

    def count_coverage(lang, group, card_or_other)
      finishes, card_prices = if card_or_other.is_a?(Other)
        [ card_or_other.finishes, card_or_other.prices ]
      else
        [ Array(card_or_other["finishes"]), prices(card_or_other) ]
      end
      finishes.each do |finish|
        next unless FINISH_KEYS.key?(finish)

        counts = @coverage[[ lang, group, finish ]]
        counts[:printings] += 1
        FINISH_KEYS.fetch(finish).each { |currency, key| counts[currency] += 1 if card_prices[key] }
      end
    end

    def keep_for_pairing(lang, card)
      if lang == "en"
        key = [ card.fetch("set"), card.fetch("collector_number") ]
        @english_sets << card.fetch("set")
        @files[:duplicate_english_keys] += 1 if @english.key?(key)
        @english[key] = English.new(prices(card).slice(*PRICE_KEYS), card["tcgplayer_id"], card["cardmarket_id"],
          Array(card["finishes"]), oracle_id(card))
      else
        @others << Other.new(lang, card.fetch("set"), card.fetch("collector_number"), card.fetch("name"),
          Array(card["finishes"]), prices(card).slice(*PRICE_KEYS), card["tcgplayer_id"], card["cardmarket_id"],
          card.fetch("id"), oracle_id(card))
      end
    end

    # As MTG::Scryfall::Mapper.identity_record reads it: the card's own, else its first face's.
    def oracle_id(card) = card["oracle_id"] || Array(card["card_faces"]).first&.dig("oracle_id")

    def pair_others
      @pairs = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      @ids = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      @ratios = Hash.new { |hash, key| hash[key] = [] }
      @examples = Hash.new { |hash, key| hash[key] = [] }
      @currencies = Hash.new(0)
      @unpaired = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      @unpaired_sets = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      @unpaired_files = Hash.new(0)
      @unpaired_file_sets = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      @finish_gaps = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      @eur_ids = Hash.new(0)
      @others.each do |other|
        english = @english[[ other.set, other.number ]]
        group = english ? "with an English twin" : "no English twin"
        count_coverage(other.lang, group, other)
        english ? compare_pair(other, english) : count_unpaired(other)
      end
    end

    # Why a non-English printing has no English printing of the same set and number, as far as the file tells.
    def unpaired_reason(other)
      return "the set has no English paper printing" unless @english_sets.include?(other.set)
      return "the English printing of that number isn't paper" if @english_not_paper.include?([ other.set, other.number ])

      if other.number.include?("★")
        base = @english.key?([ other.set, other.number.delete("★") ]) ? "in English" : "not in English"
        return "the number has a ★; the number without it is #{base}"
      end
      return "a plain number the set has no English printing of" if other.number.match?(/\A\d+\z/)

      "a number with another mark (letter or symbol) the set has no English printing of"
    end

    def count_unpaired(other)
      @ids[other.lang][:unpaired] += 1
      reason = unpaired_reason(other)
      counts = @unpaired[[ other.lang, reason ]]
      counts[:printings] += 1
      counts[:usd] += 1 if other.prices.values_at("usd", "usd_foil", "usd_etched").any?
      counts[:eur] += 1 if other.prices.values_at("eur", "eur_foil", "eur_etched").any?
      @unpaired_sets[[ other.lang, reason ]][other.set] += 1
      file = @default_ids.include?(other.id) ? :in_default : :all_only
      @unpaired_files[[ other.lang, file ]] += 1
      @unpaired_file_sets[[ other.lang, file ]][other.set] += 1
      @unpaired_files[[ other.lang, :"#{file}_priced" ]] += 1 if other.prices.except("tix").values.any?
    end

    def compare_pair(other, english)
      ids = @ids[other.lang]
      ids[:pairs] += 1
      @files[:oracle_mismatch] += 1 if other.oracle_id != english.oracle_id
      other.finishes.each do |finish|
        next unless FINISH_KEYS.key?(finish)

        usd, eur = FINISH_KEYS.fetch(finish).values_at("USD", "EUR").map { |key| outcome(english.prices[key], other.prices[key]) }
        @currencies[[ other.lang, finish, usd, eur ]] += 1
        count_finish_gap(other, english, finish)
      end
      ids[:"tcgplayer_#{id_relation(other.tcgplayer_id, english.tcgplayer_id)}"] += 1
      cardmarket = id_relation(other.cardmarket_id, english.cardmarket_id)
      ids[:"cardmarket_#{cardmarket}"] += 1
      eur = other.prices.values_at("eur", "eur_foil", "eur_etched").any? ? "with a EUR price" : "no EUR price"
      @eur_ids[[ other.lang, cardmarket, eur ]] += 1
      PRICE_KEYS.each do |key|
        outcome = outcome(english.prices[key], other.prices[key])
        @pairs[[ other.lang, key ]][outcome] += 1
        @ratios[[ other.lang, key ]] << other.prices[key].to_f / english.prices[key].to_f if outcome == :different
        keep_example(other, english, key, outcome)
      end
    end

    # A finish the non-English printing has and its English twin hasn't: the twin has no price to lend for it.
    def count_finish_gap(other, english, finish)
      return if english.finishes.include?(finish)

      counts = @finish_gaps[[ other.lang, finish ]]
      counts[:pairs] += 1
      counts[:own_priced] += 1 if other.prices.values_at(*FINISH_KEYS.fetch(finish).values).any?
      counts[:twin_priced] += 1 if english.prices.except("tix").values.any?
    end

    def id_relation(own, english)
      return "absent" unless own

      own == english ? "same" : "own"
    end

    def outcome(english, other)
      return :both_empty if english.nil? && other.nil?
      return :english_only if other.nil?
      return :other_only if english.nil?

      english == other ? :equal : :different
    end

    def keep_example(other, english, key, outcome)
      return if outcome == :both_empty

      # Every exception (a price that differs, or one the English twin lacks) is listed; the common outcomes are sampled.
      limit = if %i[different other_only].include?(outcome) then Float::INFINITY
      elsif other.lang == "ja" then EXAMPLES
      else OTHER_EXAMPLES
      end
      examples = @examples[[ other.lang, outcome ]]
      return if examples.size >= limit || examples.any? { |example| example[:number] == other.number && example[:set] == other.set }

      examples << { set: other.set, number: other.number, name: other.name, key:, english: english.prices[key],
                    other: other.prices[key], cardmarket: id_relation(other.cardmarket_id, english.cardmarket_id) }
    end

    def languages_in_order
      counts = @languages.select { |(population, _), _| population == "paper" }.transform_keys(&:last)
      %w[en ja].select { |lang| counts.key?(lang) } +
        counts.reject { |lang, _| %w[en ja].include?(lang) }.sort_by { |lang, count| [ -count[:objects], lang ] }.map(&:first)
    end

    def percent(part, whole) = whole.zero? ? "–" : format("%.1f%%", 100.0 * part / whole)

    def count(number) = number.to_s.reverse.scan(/\d{1,3}/).join(",").reverse

    def median(values)
      return "–" if values.empty?

      sorted = values.sort
      middle = sorted.size / 2
      value = sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
      format("%.2f", value)
    end

    def table(headers, rows)
      puts "| #{headers.join(" | ")} |"
      puts "|#{headers.map { "---" }.join("|")}|"
      rows.each { |row| puts "| #{row.join(" | ")} |" }
      puts
    end

    def report
      pair_others
      puts "# Counts for research 083"
      puts
      table(%w[File Lines], @files.select { |key, _| key.is_a?(String) }.map { |file, lines| [ "`#{file}`", count(lines) ] })
      report_pairing_checks
      report_languages
      report_keys
      report_coverage
      report_pairs
      report_currencies
      report_unpaired
      report_finish_gaps
      report_ids
      report_eur_ids
      report_ratios
      report_examples
      report_default
    end

    def report_languages
      %w[paper all].each do |population|
        puts "## 1#{population == "paper" ? "a" : "b"}. Card objects by language (#{population})"
        puts
        rows = languages_in_order.map do |lang|
          counts = @languages[[ population, lang ]]
          [ lang, count(counts[:objects]), count(counts[:with_prices]), count(counts[:all_empty]),
            percent(counts[:all_empty], counts[:objects]), count(counts[:tcgplayer_id]), count(counts[:cardmarket_id]),
            count(counts[:tix]) ]
        end
        table([ "Lang", "Objects", "With `prices`", "All prices empty", "Share all empty", "With `tcgplayer_id`",
                "With `cardmarket_id`", "With `tix`" ], rows)
      end
    end

    def report_keys
      puts "## 2. Price keys present (objects whose `prices` has the key)"
      puts
      keys = PRICE_KEYS | @keys_present["all"].keys
      table(%w[Key Paper All], keys.map { |key| [ "`#{key}`", count(@keys_present["paper"][key]), count(@keys_present["all"][key]) ] })
    end

    def report_coverage
      puts "## 3. Priced share by finish and currency (paper)"
      puts
      puts "Of the printings whose `finishes` list the finish, how many carry that finish's price."
      puts
      groups = [ "all", "with an English twin", "no English twin" ]
      rows = languages_in_order.flat_map do |lang|
        groups.flat_map do |group|
          next [] if lang == "en" && group != "all"

          FINISH_KEYS.keys.filter_map do |finish|
            counts = @coverage[[ lang, group, finish ]]
            next if counts[:printings].zero?

            [ lang, group, finish, count(counts[:printings]), count(counts["USD"]), percent(counts["USD"], counts[:printings]),
              count(counts["EUR"]), percent(counts["EUR"], counts[:printings]) ]
          end
        end
      end
      table([ "Lang", "Printings", "Finish", "With the finish", "USD priced", "USD share", "EUR priced", "EUR share" ], rows)
    end

    def report_pairs
      puts "## 4. Non-English printing against the English printing of the same set and number (paper)"
      puts
      rows = (languages_in_order - [ "en" ]).flat_map do |lang|
        PRICE_KEYS.filter_map do |key|
          counts = @pairs[[ lang, key ]]
          total = OUTCOMES.sum { |outcome| counts[outcome] }
          next if total.zero?

          [ lang, "`#{key}`", count(total), *OUTCOMES.map { |outcome| count(counts[outcome]) } ]
        end
      end
      table([ "Lang", "Price", "Pairs", "Both empty", "Equal", "Different", "English only", "Other language only" ], rows)
    end

    def report_currencies
      puts "## 4a. Per pair and finish: the USD outcome and the EUR outcome together (paper)"
      puts
      puts "One row per combination that occurs. A pair counts once for each finish the non-English printing lists."
      puts
      order = (languages_in_order - [ "en" ]).each_with_index.to_h
      rows = @currencies.sort_by { |(lang, finish, usd, eur), pairs| [ order.fetch(lang), FINISH_KEYS.keys.index(finish), -pairs, usd, eur ] }
        .map { |(lang, finish, usd, eur), pairs| [ lang, finish, usd.to_s.tr("_", " "), eur.to_s.tr("_", " "), count(pairs) ] }
      table([ "Lang", "Finish", "USD", "EUR", "Pairs" ], rows)
    end

    def report_unpaired
      puts "## 4b. Non-English printings with no English twin, by reason (paper)"
      puts
      order = (languages_in_order - [ "en" ]).each_with_index.to_h
      rows = @unpaired.sort_by { |(lang, reason), counts| [ order.fetch(lang), -counts[:printings], reason ] }.map do |(lang, reason), counts|
        sets = @unpaired_sets[[ lang, reason ]].sort_by { |set, printings| [ -printings, set ] }.first(5)
        [ lang, reason, count(counts[:printings]), count(counts[:usd]), count(counts[:eur]),
          sets.map { |set, printings| "#{set} #{printings}" }.join(", ") ]
      end
      table([ "Lang", "Reason", "Printings", "Any USD price", "Any EUR price", "Most common sets" ], rows)
      puts "The same printings by the file that carries them. Priced: any USD or EUR price."
      puts
      rows = (languages_in_order - [ "en" ]).map do |lang|
        sets = @unpaired_file_sets[[ lang, :all_only ]].sort_by { |set, printings| [ -printings, set ] }.first(5)
        [ lang, *%i[in_default in_default_priced all_only all_only_priced].map { |key| count(@unpaired_files[[ lang, key ]]) },
          sets.map { |set, printings| "#{set} #{printings}" }.join(", ") ]
      end
      table([ "Lang", "In `default_cards` too", "Of those, priced", "In `all_cards` only", "Of those, priced",
              "Sets of those in `all_cards` only" ], rows)
    end

    def report_pairing_checks
      puts "## 0. Pairing checks"
      puts
      table(%w[Check Count], [
        [ "English paper printings that share a set code and number with another", count(@files[:duplicate_english_keys]) ],
        [ "Pairs whose two printings have different `oracle_id`s", count(@files[:oracle_mismatch]) ]
      ])
    end

    def report_finish_gaps
      puts "## 4c. Pairs where the non-English printing has a finish its English twin hasn't (paper)"
      puts
      rows = @finish_gaps.sort_by { |(lang, finish), _| [ languages_in_order.index(lang), FINISH_KEYS.keys.index(finish) ] }
        .map { |(lang, finish), counts| [ lang, finish, *%i[pairs own_priced twin_priced].map { |key| count(counts[key]) } ] }
      table([ "Lang", "Finish", "Pairs", "Of those, the non-English printing priced for it",
              "Of those, the twin priced for a finish of its own" ], rows)
    end

    def report_eur_ids
      puts "## 5a. Pairs by the non-English printing's `cardmarket_id` and whether it has a EUR price (paper)"
      puts
      rows = @eur_ids.sort_by { |(lang, relation, eur), _| [ languages_in_order.index(lang), relation, eur ] }
        .map { |(lang, relation, eur), pairs| [ lang, relation, eur, count(pairs) ] }
      table([ "Lang", "Cardmarket id", "EUR", "Pairs" ], rows)
    end

    def report_ids
      puts "## 5. Marketplace ids of the non-English printing (paper)"
      puts
      puts "Same: equal to the English twin's. Own: present and different. Absent: none."
      puts
      rows = (languages_in_order - [ "en" ]).map do |lang|
        ids = @ids[lang]
        [ lang, count(ids[:pairs]), count(ids[:unpaired]),
          *%w[tcgplayer cardmarket].flat_map { |id| %w[same own absent].map { |relation| count(ids[:"#{id}_#{relation}"]) } } ]
      end
      table([ "Lang", "With an English twin", "No English twin", "TCGplayer same", "TCGplayer own", "TCGplayer absent",
              "Cardmarket same", "Cardmarket own", "Cardmarket absent" ], rows)
    end

    def report_ratios
      puts "## 6. Where both are priced and differ: the other language's price over the English one's"
      puts
      rows = (languages_in_order - [ "en" ]).flat_map do |lang|
        PRICE_KEYS.filter_map do |key|
          ratios = @ratios[[ lang, key ]]
          next if ratios.empty?

          sorted = ratios.sort
          [ lang, "`#{key}`", count(ratios.size), median(sorted.first((sorted.size + 1) / 2)), median(sorted),
            median(sorted.last((sorted.size + 1) / 2)) ]
        end
      end
      table([ "Lang", "Price", "Pairs", "Lower half's median", "Median", "Upper half's median" ], rows)
    end

    def report_examples
      puts "## 7. Examples (paper): every \"different\" and \"other language only\"; of each other outcome, ten for " \
           "Japanese and three for another language"
      puts
      rows = (languages_in_order - [ "en" ]).flat_map do |lang|
        (OUTCOMES - [ :both_empty ]).flat_map do |outcome|
          @examples[[ lang, outcome ]].map do |example|
            [ lang, outcome.to_s.tr("_", " "), example[:set], example[:number], example[:name], "`#{example[:key]}`",
              example[:english] || "–", example[:other] || "–", example[:cardmarket] ]
          end
        end
      end
      table([ "Lang", "Outcome", "Set", "Number", "Name", "Price", "English", "Other language", "Cardmarket id" ], rows)
    end

    def report_default
      puts "## 8. `default_cards` against `all_cards`"
      puts
      rows = [ [ "Card ids in both files", count(@files[:in_both]) ],
               [ "Of those, `prices` identical on every key", count(@files[:identical]) ],
               *PRICE_KEYS.map { |key| [ "Of those, `#{key}` differs", count(@files[:"differs_#{key}"]) ] },
               [ "Card ids in `default_cards` only", count(@default_prices.size) ] ]
      table(%w[Measure Count], rows)
      puts "Card objects in `default_cards` by language:"
      puts
      rows = @default_languages.sort_by { |lang, counts| [ lang == "en" ? 0 : 1, -counts[:objects], lang ] }.map do |lang, counts|
        [ lang, count(counts[:objects]), count(counts[:paper]), count(counts[:paper_priced]) ]
      end
      table([ "Lang", "Objects", "Paper", "Paper with any price" ], rows)
    end
end

abort "Usage: ruby #{File.basename(__FILE__)} ALL_CARDS.jsonl.gz DEFAULT_CARDS.jsonl.gz" unless ARGV.size == 2
PriceCounts.new(*ARGV).run
