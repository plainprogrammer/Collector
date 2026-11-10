# The no-script confirmation page for removing a location (spec 029 decision 6). A place only: a deck's is
# `Decks::RemovalsController`, and a zone has none (spec 062 AC-3.8).
class Locations::RemovalsController < ApplicationController
  def new
    @location = Current.account.locations.places.find(params[:location_id])
    @holdings = @location.holdings
    render :refused if @holdings.any?
  end
end
