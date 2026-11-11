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
      notice: "Moved #{@move.count} × #{@lot.entry.name} (#{helpers.set_number(@lot.entry)}) to #{to ? to.label : "no location"}."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_content
  end

  private
    def set_lot = @lot = Current.account.lots.includes({ location: :parent }, entry: :set).find(params[:lot_id])

    # The To field's choices: "No location" first unless the lot is already unplaced, then Places and Decks, the lot's own place or
    # zone left out (spec 065 decision 7). @offered says whether there is anything to move to.
    def set_destinations
      @choices = Location::Choices.new(Current.account)
      @leading = @lot.location_id ? [ [ "No location", "" ] ] : []
      @offered = @lot.location_id.present? || @choices.any?(except: @lot.location_id)
    end

    # The place or zone the To field names, nil for none; a deck's own row and any other id are 404 (spec 065 AC-2.4).
    def destination
      id = move_params[:location_id].presence
      Current.account.locations.find_placeable!(id) if id
    end

    def move_params = params.expect(move: %i[copies location_id])
end
