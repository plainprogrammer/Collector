# Spec 032 Story 3: moves some or all of one lot's copies. Every lookup goes through Current.account (decision 6).
class Lots::MovesController < ApplicationController
  before_action :set_lot
  before_action :set_destinations

  rescue_from(ActiveRecord::InvalidForeignKey) { raise ActiveRecord::RecordNotFound } # the destination was removed meanwhile

  def new
    @move = Lot::Move.new(lot: @lot, to: nil)
  end

  def create
    to = destination
    @move = Lot::Move.new(lot: @lot, to:, copies: move_params[:copies])
    @move.call!
    redirect_to catalog_entry_path(@lot.entry, **card_params), status: :see_other,
      notice: "Moved #{@move.count} × #{@lot.entry.name} (#{helpers.set_number(@lot.entry)}) to #{to ? to.name : "no location"}."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_content
  end

  private
    def set_lot = @lot = Current.account.lots.includes({ location: :parent }, entry: :set).find(params[:lot_id])

    # "No location" first unless the lot is already there, then the account's other places: the options of the To field. A deck
    # is never a destination and a zone is not offered (spec 062 AC-5.6); a lot in a zone is "somewhere" (it has a location_id),
    # so it is offered "No location" and every place, its own zone being the source.
    def set_destinations
      locations = Current.account.locations.places.ordered.reject { |location| location.id == @lot.location_id }
      @destinations = (@lot.location_id ? [ [ "No location", "" ] ] : []) + locations.map { |location| [ location.name, location.id ] }
    end

    # The place the To field names, nil for none; any other id, a deck's and a zone's included, is 404 (spec 062 AC-5.2).
    def destination
      id = move_params[:location_id].presence
      Current.account.locations.places.find(id) if id
    end

    def move_params = params.expect(move: %i[copies location_id])
end
