# Spec 029: the signed-in collector's locations. Every lookup goes through Current.account, so another account's id is a
# 404; nothing in a request names an account.
#
# These pages know places only (spec 062 AC-3.8, AC-4.8): a deck is renamed and removed as a deck, through its own pages
# (`DecksController`), which check what it holds and remove its zones with it, and a zone is never renamed, removed or
# opened in bulk mode on its own. So every lookup here is `Current.account.locations.places`, and the id of a deck or a
# zone is a 404, never a way round the deck's pages.
class LocationsController < ApplicationController
  before_action :set_location, only: %i[edit update destroy]

  def index
    @location = Location.new
    @locations = Current.account.locations.places.ordered.to_a
    @holdings = Location::Holdings.counts(Current.account)
  end

  def create
    @location = Current.account.locations.places.new(name: location_name)
    if @location.save
      redirect_to locations_path, notice: "Added “#{@location.name}”.", status: :see_other
    else
      @locations = Current.account.locations.places.ordered.to_a
      @holdings = Location::Holdings.counts(Current.account)
      render :index, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    before = @location.name
    @location.name = location_name
    if @location.save
      redirect_to locations_path, notice: "Renamed “#{before}” to “#{@location.name}”.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # A location that holds lots is refused (spec 032 decision 3), here and in the database: a lot put in it after the
  # confirmation page opened is caught by the check, one put in it between the check and the delete by the foreign key.
  # Removing a location never changes a lot (spec 029 decision 3).
  def destroy
    holdings = @location.holdings
    return refuse(holdings) if holdings.any?

    @location.destroy!
    redirect_to locations_path, notice: "Removed “#{@location.name}”.", status: :see_other
  rescue ActiveRecord::InvalidForeignKey
    refuse(@location.holdings)
  end

  private
    def refuse(holdings)
      @holdings = holdings
      render "locations/removals/refused", status: :conflict
    end

    def set_location = @location = Current.account.locations.places.find(params[:id])

    # The one permitted parameter; a request without the location parameter is a 400.
    def location_name = params.expect(location: [ :name ])[:name]
end
