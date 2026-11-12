# Use my copy's form object (spec 070 Stories 2 and 3): the free lots of a proxy's card as the page lists them, and the
# replacement of the proxy by the copies the collector chose, lot by lot. One transaction does it all: judged under the write
# lock against a fresh read, moved through `Lot::MoveIntoZone` (which goes through `Lot::Move`), then the proxy lowered by the
# copies used or removed at zero.
#
# What the form posts: `lots[<lot id>]` (the number typed, blank is 0) and `shown[<lot id>]` (the lot's quantity as the page
# drew it). A chosen lot whose quantity is no longer the shown one, or that is no longer free, is refused: that is what makes a
# second submit of one form (two tabs, a double click) refuse instead of moving twice (decision 9). A refused page is built
# again from a fresh read with every `shown` written again and the typed numbers kept, so correcting and submitting again works.
#
# Not for reuse beyond the page: "Add to deck" (spec 071) takes its lots from its own count and uses `Lot::MoveIntoZone`.
# @see file:collection-and-lots.md
class Deck::Proxy::UseCopies
  CHANGED = "Those copies changed. Check the numbers and try again.".freeze
  NOT_OFFERED = "Edit this copy first: its finish or condition isn't offered any more.".freeze

  # One lot as the page draws it: the lot, what was typed for it ("0" at first), the quantity the page now shows for it and its
  # sentences.
  Row = Data.define(:lot, :typed, :shown, :errors)

  # @return [Deck::Proxy] the proxy being replaced (read again by {#save})
  attr_reader :proxy
  # @return [Array<String>] the sentences for the lots' fieldset
  attr_reader :fieldset_errors
  # @return [Integer, nil] the copies used by a successful {#save}
  attr_reader :used

  # @param proxy [Deck::Proxy] a proxy found through the signed-in account's deck
  # @param typed [Hash] `lots` as posted: lot id => text
  # @param shown [Hash] `shown` as posted: lot id => the quantity the page showed, as text
  def initialize(proxy:, typed: {}, shown: {})
    @proxy = proxy
    @typed = typed.to_h.transform_keys(&:to_s)
    @shown = shown.to_h.transform_keys(&:to_s)
    @fieldset_errors = []
    @field_errors = Hash.new { |errors, id| errors[id] = [] }
  end

  # The account's free lots of the proxy's card, any printing, in the order of the card page's "Your copies" (newest printing,
  # finish, condition, price paid, place); retired printings included. Read once per state of the world: {#save} forgets it, so
  # a page drawn after a refusal reads again.
  #
  # @return [Array<Lot>]
  def free_lots
    @free_lots ||= proxy.account.lots.free.joins(:entry).left_joins(:location)
      .where(catalog_entries: { catalog_identity_id: proxy.entry.catalog_identity_id })
      .includes(entry: :set).preload(:location).merge(Catalog::Entry.newest_first)
      .order(:finish, :condition, :price_paid_cents)
      .order(Location.arel_table[:name_key].asc, Location.arel_table[:name].asc).to_a
  end

  # The lots in their groups, a group with no lot left out: "This printing" (the proxy's printing and finish) then "Other
  # printings" (everything else, another finish of the printing included).
  #
  # @return [Array<Array(String, Array<Row>)>]
  def groups
    own, rest = rows.partition { |row| row.lot.catalog_entry_id == proxy.catalog_entry_id && row.lot.finish == proxy.finish }
    [ [ "This printing", own ], [ "Other printings", rest ] ].reject { |_name, in_group| in_group.empty? }
  end

  # The free lots as {Row}s, in the lots' order: what was typed for each ("0" at first), the quantity to show and its sentences.
  #
  # @return [Array<Row>]
  def rows
    free_lots.map { |lot| Row.new(lot:, typed: @typed.fetch(lot.id.to_s, "0"), shown: lot.quantity, errors: @field_errors[lot.id].dup) }
  end

  # Replaces the proxy by the chosen copies, or says why not.
  #
  # @return [Boolean] false, with sentences on {#fieldset_errors} and the rows, when nothing was written
  # @raise [ActiveRecord::RecordNotFound] when the proxy was removed meanwhile (a 404)
  def save
    @fieldset_errors, @field_errors, @used = [], Hash.new { |errors, id| errors[id] = [] }, nil
    done = Lot.transaction do
      proxy.reload # the proxy's count now, under the write lock
      @free_lots = nil
      @picks = judge
      next false if invalid?

      Lot::MoveIntoZone.new(account: proxy.account, zone: proxy.zone, picks: @picks).call!
      proxy.lower_by!(@used = @picks.sum(&:last))
      true
    end
    @free_lots = nil unless done # the page is drawn from a read made after the transaction
    done
  rescue Lot::MoveIntoZone::Refused => refused
    @free_lots = nil
    absorb(refused)
    false
  end

  private
    def invalid? = @fieldset_errors.any? || @field_errors.values.any?(&:any?)

    # Parses what was typed, checks each chosen lot against the fresh read and the sum against the proxy's count. Returns the
    # `[lot, count]` pairs to move; the sentences are on the form.
    def judge
      lots = free_lots.index_by { |lot| lot.id.to_s }
      picks = []
      @typed.each do |key, text|
        next unless key.match?(Location::ID_TEXT)

        count = parse(text)
        lot = lots[key]
        if lot.nil?
          changed if count&.positive?
          next
        end
        field(lot, "Enter a number from 0 to #{number(lot.quantity)}.") if count.nil? || count > lot.quantity
        next unless count&.positive?

        field(lot, NOT_OFFERED) unless lot.valid? # a finish or condition the vocabulary no longer lists: judged with the other checks (decision 9); MoveIntoZone's own check is the backstop

        changed unless @shown[key].to_s.match?(/\A\d+\z/) && @shown[key].to_i == lot.quantity
        picks << [ lot, count ] if count <= lot.quantity
      end
      check_sum(picks) unless invalid?
      picks
    end

    def check_sum(picks)
      return if picks.sum(&:last).between?(1, proxy.quantity)

      @fieldset_errors << "Enter a number from 1 to #{number(proxy.quantity)}."
    end

    # A whole number from 0 up as typed, blank as 0, anything else nil.
    def parse(text)
      text = text.to_s.strip
      return 0 if text.empty?

      Integer(text, 10, exception: false)&.then { it if it >= 0 }
    end

    def changed = (@fieldset_errors << CHANGED unless @fieldset_errors.include?(CHANGED))

    def field(lot, sentence) = @field_errors[lot.id] << sentence

    def number(count) = ActiveSupport::NumberHelper.number_to_delimited(count)

    # `Lot::MoveIntoZone`'s reasons as this page says them.
    def absorb(refused)
      refused.reasons.each do |id, reason|
        case reason
        when :cap then @field_errors[id] << Lot::FULL_MESSAGE
        when :not_saveable then @field_errors[id] << NOT_OFFERED
        else changed
        end
      end
    end
end
