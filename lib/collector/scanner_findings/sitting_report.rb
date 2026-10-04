# Spec 009 AC-9.1: the live sitting, scored. Each manifest row's captures carry the reading keys the page minted. The events
# measurement mode recorded (AC-9.2) and the sitting entries those keys made give the outcome: the printing and finish the
# card ended as (read from its lot, so an edit counts), against the row's ground truth, and the corrections on the way. Run it
# before "Done", which discards the entries. Medians here are conventional: the mean of the middle two for an even count.
class Collector::ScannerFindings::SittingReport
  KINDS = [ "right first time", "right after a correction", "wrong", "not added" ].freeze
  CORRECTIONS = [ "a candidate other than the first", "Other printings", "Undo and re-add", "details edited" ].freeze

  Outcome = Data.define(:file, :truth, :entry, :finish, :corrections, :scans, :name_text, :collector_text) do
    def added? = !entry.nil?
    def right? = added? && entry.printing.external_key == truth["external_key"] && finish == truth["finish"]

    def kind
      if !added? then "not added"
      elsif !right? then "wrong"
      elsif corrections.any? then "right after a correction"
      else "right first time"
      end
    end
  end

  def initialize(run:, account:, ground_truth:)
    @run = run
    @account = account
    @truth = JSON.parse(Pathname(ground_truth).expand_path.read).fetch("photos").to_h { [ it["file"], it ] }
  end

  def outcomes
    @outcomes ||= @run.rows.filter_map do |row|
      next unless (truth = @truth[row.file])

      captures = @run.captures(row)
      keys = captures.filter_map { it["reading_key"] }
      final = Scanner::SittingEntry.kept.where(account: @account, reading_key: keys).includes(:lot, printing: :set).order(:created_at).last
      Outcome.new(file: row.file, truth:, entry: final, finish: final && (final.lot ? final.lot.finish : final.finish),
        corrections: corrections(@run.events(row)), scans: captures.size,
        name_text: captures.first&.fetch("name_text", nil), collector_text: captures.first&.fetch("collector_text", nil))
    end
  end

  # Seconds from the previous add to each add, in the order the adds happened; the first add has none.
  def times
    adds = @run.rows.flat_map { @run.events(it) }.select { it["kind"] == "add" }.map { Time.iso8601(it["at"]) }.sort
    adds.each_cons(2).map { |earlier, later| (later - earlier).round(1) }
  end

  def to_markdown
    groups = { "all" => outcomes, "foil" => outcomes.select { it.truth["foil"] }, "non-foil" => outcomes.reject { it.truth["foil"] } }
    rows = groups.map { |label, list| "| #{label} | #{KINDS.map { |kind| "#{list.count { it.kind == kind }}/#{list.size}" }.join(" | ")} |" }
    corrections = CORRECTIONS.map { |kind| "#{kind}: #{outcomes.count { it.corrections.include?(kind) }}" }.join("; ")
    seconds = times
    others = outcomes.reject { it.kind == "right first time" }.map do |outcome|
      "| #{outcome.file} | #{label(outcome.truth["name"], outcome.truth["set_code"], outcome.truth["collector_number"], outcome.truth["finish"])} | " \
        "#{outcome.added? ? label(outcome.entry.printing.name, outcome.entry.printing.set.code, outcome.entry.printing.number, outcome.finish || "—") : "—"} | " \
        "#{outcome.kind} | #{outcome.corrections.join("; ").presence || "—"} | #{cell(outcome.name_text)} | #{cell(outcome.collector_text)} | |"
    end
    [ "| Cards | #{KINDS.join(" | ")} |", "|---|---|---|---|---|", *rows, "", "Corrections (a card can have several): #{corrections}.", "",
      "Time per card, from the previous add (conventional median): median #{median(seconds) || "n/a"} s, slowest #{seconds.max || "n/a"} s (n=#{seconds.size}).",
      "", "| File | Expected | Ended as | Outcome | Corrections | Name strip | Collector strip | Likely cause |", "|---|---|---|---|---|---|---|---|",
      *others ].join("\n")
  end

  private
    def corrections(events)
      ranks = events.select { it["kind"] == "add" }.map { it["rank"] }
      [ ("a candidate other than the first" if ranks.any? { %w[2 3].include?(it) }), ("Other printings" if ranks.include?("other")),
        ("Undo and re-add" if events.any? { it["kind"] == "undo" }), ("details edited" if events.any? { it["kind"] == "details" }) ].compact
    end

    def median(values)
      return nil if values.empty?

      sorted = values.sort
      middle = sorted.size / 2
      sorted.size.odd? ? sorted[middle] : ((sorted[middle - 1] + sorted[middle]) / 2.0).round(1)
    end

    def label(name, set_code, number, finish) = "#{name} (#{set_code.upcase} · #{number}, #{finish})"

    def cell(text) = text.to_s.gsub("|", "\\|").gsub(/\s+/, " ")
end
