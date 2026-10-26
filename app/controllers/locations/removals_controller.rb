# The no-script confirmation page for removing a location (spec 029 decision 6).
class Locations::RemovalsController < ApplicationController
  def new
    @location = Current.account.locations.find(params[:location_id])
    @holdings = @location.holdings
    render :refused if @holdings.any?
  end
end
