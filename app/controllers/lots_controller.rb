class LotsController < ApplicationController
  before_action :set_entry, only: %i[new create]
  before_action :set_lot, only: %i[edit update destroy]
  before_action :set_choices, only: %i[new create edit update]

  # The location chosen in the form was removed after it was found: the foreign key refused the write (spec 032 AC-6.7).
  rescue_from(ActiveRecord::InvalidForeignKey) { raise ActiveRecord::RecordNotFound }

  def new
    @form = Lot::Form.new(entry: @entry)
  end

  def create
    location = chosen_location
    @form = Lot::Form.new(**lot_params.to_h.symbolize_keys, entry: @entry)
    return render(:new, status: :unprocessable_content) unless @form.valid?

    attributes = @form.lot_attributes
    Lot.add!(account: Current.account, entry: @entry, location:, **attributes)
    redirect_to catalog_entry_path(@entry, **card_params), status: :see_other,
      notice: "Added #{attributes[:quantity]} × #{@entry.name} (#{helpers.set_number(@entry)}) to #{location ? location.label : "your collection"}."
  rescue ActiveRecord::RecordInvalid => error
    @form.absorb(error.record)
    render :new, status: :unprocessable_content
  end

  def edit
    @form = Lot::Form.from(@lot)
  end

  def update
    place = lot_params.key?(:location_id) ? chosen_location : @lot.location # absent keeps the place; blank is "No location" (spec 032 O3)
    @form = Lot::Form.new(**{ location_id: @lot.location_id&.to_s }.merge(lot_params.to_h.symbolize_keys), entry: @lot.entry)
    return render(:edit, status: :unprocessable_content) unless @form.valid?

    @lot.revise!(@form.lot_attributes.merge(location: place))
    redirect_to lot_return_path(@lot.entry), status: :see_other, notice: "Saved."
  rescue ActiveRecord::RecordInvalid
    @form.absorb(@lot)
    render :edit, status: :unprocessable_content
  end

  def destroy
    @lot.destroy!
    BulkRemoval.supersede!(Current.session)
    redirect_to lot_return_path(@lot.entry), status: :see_other,
      notice: "Removed #{@lot.quantity} × #{@lot.entry.name} (#{helpers.set_number(@lot.entry)}) from your collection."
  end

  private
    def set_entry = @entry = Catalog::Entry.includes(:set).find_by!(external_key: params[:entry_external_key])

    # The lot's place and its deck are joined into the lot's own statement (not preloaded): a separate lookup of the lot's place
    # would come before the lookup of the place the form names, and the race of spec 032 AC-6.7 needs that order the other way.
    def set_lot = @lot = Current.account.lots.eager_load(location: :parent).includes(entry: :set).find(params[:id])

    # What the form's Location select offers: the account's places and the zones of its decks (spec 065 decision 2).
    def set_choices = @choices = Location::Choices.new(Current.account)

    # The place or zone the form names, nil for none; a deck's own row, another account's location, a missing one and text that
    # isn't an id are 404 (spec 065 AC-1.7). Its parent is loaded so the notice can read "Deck › Zone".
    def chosen_location
      id = lot_params[:location_id].presence
      Current.account.locations.find_placeable!(id) if id
    end

    def lot_params = params.expect(lot: %i[quantity finish condition price_paid location_id])
end
