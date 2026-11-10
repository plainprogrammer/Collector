# The refusal page's shortcut into bulk mode (spec 059, #187): starts the session's bulk selection under one of the
# account's locations with every matching lot selected, and goes to the bulk table. It is the sequence spec 041 decision 5
# described (filter, Edit many, select every matching lot) in one POST, a form button because Edit many is never a link
# (spec 006 FR-1). The location in the path is the only parameter read.
#
# @see file:collection-and-lots.md
class Locations::SelectionsController < ApplicationController
  # 404 for a location that isn't the account's (spec 059 AC-4.1). Replaces any stored selection, as Edit many does.
  def create
    location = Current.account.locations.find(params[:location_id])
    sort = CollectionTable::Sort.parse(nil, nil)
    BulkSelection.for(Current.session).restart!(query: "", sort:, location: location.id.to_s, all: true)
    redirect_to helpers.collection_listing_path(bulk: 1, location: location.id.to_s, sort:), status: :see_other
  end
end
