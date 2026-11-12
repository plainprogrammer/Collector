# The Add to deck page's form (spec 071): a zone, a count and a choice of what to use, checked and written in one call. "My
# copies" moves the card's free copies into the zone in the order `Lot::FreeCopies` gives; a proxy is recorded through
# `Deck::Proxy.add!`. A sentence lands on the field it belongs to; what was typed stays for the page to show again.
#
# The zone must be one of the account's zones of a deck of the printing's collectible type (`Location::Choices#decks_of`): any
# other value is `ActiveRecord::RecordNotFound` (a 404), never an error on the form, so no sentence tells another account's
# zone from a missing one. Collectible-agnostic: finishes and category words come from the printing's vocabulary.
# @see file:collection-and-lots.md
class Deck::Addition
  include ActiveModel::Model
  include ActiveModel::Attributes

  CHOOSE_ZONE = "Choose a deck and zone.".freeze
  CHOOSE_USE = "Choose what to use.".freeze
  USE_SHAPE = /\A(copies|proxy|proxy:.+)\z/

  # One radio of "What to use": its value (`copies`, `proxy:<finish key>` or `proxy`), its kind and the finish key for a proxy.
  Use = Data.define(:value, :kind, :finish)

  attribute :zone_id, :string
  attribute :quantity, :string, default: "1"
  attribute :use, :string

  attr_reader :account, :entry, :zone, :count, :proxy

  # @param account [Account] the signed-in account
  # @param entry [Catalog::Entry] the shown printing, `deck_addable?`
  def initialize(account:, entry:, **fields)
    super(**fields)
    @account, @entry = account, entry
  end

  # The decks the card can be added to, with their zones.
  #
  # @return [Array<Location::Choices::Group>] the account's decks of the printing's type with their zones
  def groups = @groups ||= Location::Choices.new(account).decks_of(entry.collectible_type)

  # Whether the account has a deck to add the card to; with none the page shows a sentence and no form (decision 12).
  #
  # @return [Boolean]
  def decks? = groups.any?

  # The card's free copies as the page shows them; {#save} reads them again under the write lock, so this is never what a take
  # is judged on.
  #
  # @return [Lot::FreeCopies] as of the first call
  def free = @free ||= Lot::FreeCopies.new(account:, entry:)

  # The radios of "What to use" in page order: My copies when copies are free, then one proxy per finish the printing lists, or
  # one with no finish for a printing that lists none (decision 9).
  #
  # @return [Array<Use>]
  def uses
    @uses ||= begin
      copies = free.total.positive? ? [ Use.new("copies", :copies, nil) ] : []
      finishes = vocabulary.finishes_for(entry)
      proxies = finishes.empty? ? [ Use.new("proxy", :proxy, nil) ] : finishes.map { |finish| Use.new("proxy:#{finish}", :proxy, finish) }
      copies + proxies
    end
  end

  # The radio to check when the page is drawn: what was submitted when that is still an option (after "no free copy" the page
  # draws without My copies, so a submitted `copies` is no longer one), else the only option when there is just one
  # (spec 060 decision 14).
  #
  # @return [String, nil]
  def chosen = (use if uses.any? { |option| option.value == use }) || (uses.first.value if uses.one?)

  # A proxy option's finish in the vocabulary's words ("Foil").
  #
  # @param use [Use]
  # @return [String, nil] nil for a proxy with none
  def finish_label(use) = use.finish && vocabulary.finish_label(use.finish)

  # Checks and writes.
  #
  # @return [Boolean] false, with sentences on `errors`, when nothing was written
  # @raise [ActiveRecord::RecordNotFound] for a zone that is not one of the offered zones, or removed while the request ran
  def save
    errors.clear
    offered = zone_id.blank? ? nil : offered_zone!
    errors.add(:zone_id, CHOOSE_ZONE) if offered.nil?
    errors.add(:use, CHOOSE_USE) unless USE_SHAPE.match?(use.to_s)
    return false if errors.any?

    use == "copies" ? take(offered) : add_proxy(offered)
  end

  private
    def vocabulary = Catalog.collecting_for(entry.collectible_type)

    def offered_zone!
      groups.flat_map(&:zones).find { |candidate| candidate.id.to_s == zone_id.to_s } || raise(ActiveRecord::RecordNotFound, "no such zone")
    end

    # One write transaction that finds the zone, reads the free copies, chooses the picks and moves them, so the count is judged
    # on what is free at the write (AC-3.8). `Refused` leaves the block before it is mapped to a sentence: `Lot::Move` joins this
    # transaction, so a rescue inside it would commit the earlier moves.
    def take(offered)
      fresh = nil
      Lot.transaction do
        @zone = account.locations.find_placeable!(offered.id)
        fresh = Lot::FreeCopies.new(account:, entry:)
        total = fresh.total
        wanted = Integer(quantity.to_s.strip, 10, exception: false)
        if total.zero?
          errors.add(:use, "You have no free copy of #{entry.name} to use.")
        elsif wanted.nil? || !wanted.between?(1, total)
          errors.add(:quantity, "Enter a number from 1 to #{ActiveSupport::NumberHelper.number_to_delimited(total)}.")
        else
          @count = Lot::MoveIntoZone.new(account:, zone: @zone, picks: fresh.take(wanted)).call!
        end
      end
      errors.empty?
    rescue Lot::MoveIntoZone::Refused => error
      refuse(error, fresh)
    end

    # A refusal of the move as a sentence naming the first lot: the cap, or a lot that fails its own validation. The other
    # reasons (`:not_free`, `:count`) can't happen here, the picks having been chosen under the same lock, and read as the
    # second.
    def refuse(error, fresh)
      id, reason = error.reasons.first
      lot = fresh.lots.find { |candidate| candidate.id == id }
      what = reason == :cap ? "would have more than #{ActiveSupport::NumberHelper.number_to_delimited(Lot::MAX_QUANTITY)} copies in one lot." : "can't be moved until it is edited."
      errors.add(:base, "Nothing changed. #{lot.entry.name} (#{lot.entry.set.code.upcase} · #{lot.entry.number}) #{what}")
      false
    end

    def add_proxy(offered)
      @count = Deck::Proxy.parse_quantity(quantity)
      return refuse_text(:quantity, Deck::Proxy::Addition::QUANTITY_SENTENCE) unless @count

      @zone = offered
      finish = use.delete_prefix("proxy").delete_prefix(":").presence
      @proxy = Deck::Proxy.add!(account:, zone: @zone, entry:, finish:, quantity: @count)
      true
    rescue ActiveRecord::RecordInvalid => error
      error.record.errors.each do |message|
        attribute = { quantity: :quantity, finish: :use }.fetch(message.attribute, :base)
        errors.add(attribute, message.message)
      end
      false
    end

    def refuse_text(attribute, sentence)
      errors.add(attribute, sentence)
      false
    end
end
