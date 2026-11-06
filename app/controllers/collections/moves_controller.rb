# Moving every copy of the selected lots to one location, or to none, from its own page (spec 041). A bulk action like Set
# condition: the page's ticks were recorded first, and every answer returns to the bulk table it came from.
class Collections::MovesController < ApplicationController
  include BulkSelected

  before_action :require_locations
  before_action :set_destinations

  rescue_from(ActiveRecord::InvalidForeignKey) { raise ActiveRecord::RecordNotFound } # the destination was removed meanwhile

  def new
    @copies = @selection.copies
    @to = ""
  end

  private
    # The order of answers (decision 6): BulkSelected has answered a GET with nothing selected; an account with no location
    # has nothing to move to, whatever was submitted. The selection is kept.
    def require_locations
      redirect_to @bulk_path, status: :see_other, alert: Lot::BulkMove::NO_LOCATIONS unless Current.account.locations.exists?
    end

    # The To field's options: the prompt (""), "No location" ("none", the location filter's word, spec 037 decision 1), then the
    # account's locations in the locations page's order; the selection's own place is left out (AC-2.1).
    def set_destinations
      own = @selection ? @selection.location_filter : ""
      locations = Current.account.locations.ordered.reject { |location| location.id.to_s == own }
      @destinations = [ [ "Choose…", "" ] ] + (own == CollectionFilter::Place::NONE ? [] : [ [ "No location", CollectionFilter::Place::NONE ] ]) +
        locations.map { |location| [ location.name, location.id ] }
    end
end
