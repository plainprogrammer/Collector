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
    def set_lot = @lot = Current.account.lots.includes(:location, entry: :set).find(params[:lot_id])

    # "No location" first unless the lot is already there, then the account's other locations: the options of the To field.
    def set_destinations
      locations = Current.account.locations.ordered.reject { |location| location.id == @lot.location_id }
      @destinations = (@lot.location_id ? [ [ "No location", "" ] ] : []) + locations.map { |location| [ location.name, location.id ] }
    end

    def destination
      id = move_params[:location_id].presence
      Current.account.locations.find(id) if id
    end

    def move_params = params.expect(move: %i[copies location_id])
end
