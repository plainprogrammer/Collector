# Moves chosen copies of an account's free lots into one zone of a deck, all or nothing (spec 070 decisions 7 and 8). It is the
# one move of "these lots, this many copies each" into a zone: Use my copy (spec 070) hands it the collector's numbers, and
# "Add to deck" (spec 071) hands it the lots its count takes. It decides nothing about which lots or how many.
#
# It goes through `Lot::Move`, which splits a lot, merges into the zone's lot of the same identity, keeps the 9,999 cap and
# rebuilds the lot key with the zone's id. What it adds is judging every pick before the first write, under the write lock:
# each lot is read again among the account's *free* lots (so a lot taken into a zone, removed, or another account's is
# `:not_free`), its count is checked against the copies it holds now, and a lot the vocabulary can no longer save (a finish or
# condition it no longer lists; `Lot` validates both on save) is `:not_saveable` rather than moved without validation. A `:cap`
# refusal can only be found while moving, so it leaves the transaction by the exception below and the earlier moves roll back.
#
# "Free" is `Lot.free`: in no deck zone (unplaced or in a place; spec 057's "Free to use"). It takes the account explicitly and
# never reads `Current.account`.
#
# Transactions: it works nested inside a caller's transaction, by plain participation (`Lot.transaction` without
# `requires_new`: no savepoint), so a caller that has read the free lots and chosen the picks under its own write lock, or that
# lowers a proxy in the same transaction, keeps one transaction and one rollback. Called on its own it opens one (SQLite's is
# IMMEDIATE, so the reads below are under the lock). A refusal leaves by an exception, never a false return, and nothing in
# here rescues it; a caller must not rescue it inside its transaction either, or the earlier moves stay. Names no collectible.
#
# Refusals: {Refused#reasons} names every lot that can't move, by id, with one reason each: `:cap` (the zone's lot of its
# identity would pass 9,999, which is `Lot::FULL_MESSAGE`'s case) is told apart from `:not_saveable` (the lot fails its own
# validation, a finish or condition the vocabulary no longer lists), `:not_free`, and `:count`.
class Lot::MoveIntoZone
  # Why one lot can't be moved. `reasons` maps a lot's id to one of `:not_free` (no longer one of the account's free lots),
  # `:count` (not from 1 to the copies it holds now), `:not_saveable` (the lot can't be saved as it is) and `:cap` (the zone's
  # lot of its identity would hold more than 9,999; only the first such lot is named, because the moves stop there).
  class Refused < StandardError
    # @return [Hash{Integer => Symbol}]
    attr_reader :reasons

    # @param reasons [Hash{Integer => Symbol}]
    def initialize(reasons)
      @reasons = reasons
      super("lots can't be moved into the zone: #{reasons.inspect}")
    end
  end

  # @param account [Account] the signed-in account; its free lots are the only ones that move
  # @param zone [Location] a zone (kind `deck_zone`) of the account
  # @param picks [Array<Array(Lot, Integer)>] pairs of a lot and the copies to move; a lot appears once; only the lot's id is
  #   used, the lot is read again
  # @raise [ArgumentError] when the zone is not a zone of the account or a lot is named twice (programming errors)
  def initialize(account:, zone:, picks:)
    raise ArgumentError, "not a zone of the account" unless zone.zone? && zone.account_id == account.id

    ids = picks.map { |lot, _count| lot.id }
    raise ArgumentError, "a lot is named twice" unless ids.uniq.size == ids.size

    @account, @zone, @picks = account, zone, picks.map { |lot, count| [ lot.id, count ] }
  end

  # Moves the picked copies. One transaction: judged first, then moved lot by lot.
  #
  # @return [Integer] the copies moved
  # @raise [Refused] when any pick is refused; nothing is changed (a `:cap` found part way rolls the earlier moves back)
  def call!
    Lot.transaction do
      current = @account.lots.free.where(id: @picks.map(&:first)).index_by(&:id)
      reasons = judge(current)
      raise Refused, reasons if reasons.any?

      @picks.sum { |id, count| move(current.fetch(id), count) }
    end
  end

  private
    # Every refused pick with its reason, none moved yet.
    def judge(current)
      @picks.each_with_object({}) do |(id, count), reasons|
        lot = current[id]
        reason = if lot.nil? then :not_free
        elsif !count.is_a?(Integer) || !count.between?(1, lot.quantity) then :count
        elsif !lot.valid? then :not_saveable
        end
        reasons[id] = reason if reason
      end
    end

    # `Lot::Move` raises for itself, with `Lot::FULL_MESSAGE` on `copies` for the cap and no message for a lot or twin it can't
    # save; the pre-checks above make its own range sentences impossible here.
    def move(lot, count)
      Lot::Move.new(lot:, to: @zone, copies: count.to_s).call!
      count
    rescue ActiveRecord::RecordInvalid => error
      raise Refused, { lot.id => error.record.errors[:copies].include?(Lot::FULL_MESSAGE) ? :cap : :not_saveable }
    end
end
