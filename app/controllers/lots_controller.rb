class LotsController < ApplicationController
  before_action :set_entry, only: %i[new create]
  before_action :set_lot, only: %i[edit update destroy]
  before_action :set_locations, only: %i[new create edit update]
  before_action :set_zone_label, only: %i[edit update]

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
      notice: "Added #{attributes[:quantity]} × #{@entry.name} (#{helpers.set_number(@entry)}) to #{location ? location.name : "your collection"}."
  rescue ActiveRecord::RecordInvalid => error
    @form.absorb(error.record)
    render :new, status: :unprocessable_content
  end

  def edit
    @form = Lot::Form.from(@lot)
  end

  def update
    # A lot in a zone keeps it: the form shows it read-only and `lot_params` takes no location for it (spec 062 AC-5.5, D6).
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

    # The lot's place and its deck are joined into the lot's own statement (not preloaded): the form's label needs them, and a
    # separate lookup of the lot's place would come before the lookup of the place the form names (spec 032 AC-6.7's race).
    def set_lot = @lot = Current.account.lots.eager_load(location: :parent).includes(entry: :set).find(params[:id])

    # "Deck › Zone" when the lot being edited is in a zone, nil otherwise: what the form shows in place of the Location select.
    def set_zone_label = @zone_label = (@lot.place_label if @lot.location&.zone?)

    # The form's Location select lists places only (spec 062 D6): a deck is never a lot's place, and a zone is chosen by a
    # later spec's picker, not by this select.
    def set_locations = @locations = Current.account.locations.places.ordered.to_a

    # The account's place the form names, nil for none; another account's, a missing one, a deck's or a zone's id and text that
    # isn't an id are 404 (spec 062 AC-5.2).
    def chosen_location
      id = lot_params[:location_id].presence
      Current.account.locations.places.find(id) if id
    end

    # A lot in a zone permits no location, so a request that names one can't move it (the form doesn't send one); a place's lot,
    # an unplaced lot and a new lot permit it as before (spec 032 O3).
    def lot_params = params.expect(lot: @zone_label ? %i[quantity finish condition price_paid] : %i[quantity finish condition price_paid location_id])
end
