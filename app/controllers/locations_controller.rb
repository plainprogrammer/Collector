# Spec 029: the signed-in collector's locations. Every lookup goes through Current.account, so another account's id is a
# 404; nothing in a request names an account.
class LocationsController < ApplicationController
  before_action :set_location, only: %i[edit update destroy]

  def index
    @location = Location.new
    @locations = Current.account.locations.ordered.to_a
  end

  def create
    @location = Current.account.locations.new(name: location_name)
    if @location.save
      redirect_to locations_path, notice: "Added “#{@location.name}”.", status: :see_other
    else
      @locations = Current.account.locations.ordered.to_a
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

  # Removing a location never touches a lot (spec 029 decision 3).
  def destroy
    @location.destroy!
    redirect_to locations_path, notice: "Removed “#{@location.name}”.", status: :see_other
  end

  private
    def set_location = @location = Current.account.locations.find(params[:id])

    # The one permitted parameter; a request without the location parameter is a 400.
    def location_name = params.expect(location: [ :name ])[:name]
end
