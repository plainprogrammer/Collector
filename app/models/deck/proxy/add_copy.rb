# Add a new copy's form object (spec 070 Story 4): the Add a copy form (`Lot::Form`) for the proxy's printing, whose copy lands
# in the proxy's zone through `Lot.add!` (merging as every add does) while the proxy is lowered by the same quantity, in one
# transaction. The form posts the proxy's count as it showed it (`shown_quantity`): a proxy that is not that count any more is
# refused, which is what stops a second submit of one form from adding twice (decision 10).
#
# Sentences, in this order: the form's own (`Lot::Form`'s, a quantity that isn't a whole number from 1 to 9,999 included), then
# "This proxy changed…", then "Enter a number from 1 to N." (N the proxy's count now).
# @see file:collection-and-lots.md
class Deck::Proxy::AddCopy
  CHANGED = "This proxy changed. Check the quantity and try again.".freeze

  # @return [Deck::Proxy] the proxy being replaced, read again by {#save}
  attr_reader :proxy
  # @return [Lot::Form] the form, with its sentences after a refused {#save}
  attr_reader :form
  # @return [Integer, nil] the copies added by a successful {#save}
  attr_reader :added

  # @param proxy [Deck::Proxy] a proxy found through the signed-in account's deck
  # @param form [Lot::Form] built for the proxy's printing from the permitted fields (never a location)
  # @param shown_quantity [String, nil] the proxy's count as the form showed it
  def initialize(proxy:, form:, shown_quantity:)
    @proxy, @form, @shown_quantity = proxy, form, shown_quantity
  end

  # Adds the copy and lowers the proxy, or says why not.
  #
  # @return [Boolean] false, with the sentence on the form's `quantity` or the field the lot's refusal belongs to, when nothing
  #   was written
  # @raise [ActiveRecord::RecordNotFound] when the proxy was removed meanwhile (a 404)
  def save
    Lot.transaction do
      proxy.reload # its count now, under the write lock
      next false unless acceptable?

      quantity = form.lot_attributes[:quantity]
      Lot.add!(account: proxy.account, entry: proxy.entry, location: proxy.zone, **form.lot_attributes)
      proxy.lower_by!(@added = quantity)
      true
    end
  rescue ActiveRecord::RecordInvalid => error
    form.absorb(error.record)
    proxy.reload
    false
  end

  private
    def acceptable?
      return false unless form.valid?

      if @shown_quantity.to_s != proxy.quantity.to_s
        form.errors.add(:quantity, CHANGED)
      elsif form.lot_attributes[:quantity] > proxy.quantity
        form.errors.add(:quantity, "Enter a number from 1 to #{ActiveSupport::NumberHelper.number_to_delimited(proxy.quantity)}.")
      end
      form.errors.empty?
    end
end
