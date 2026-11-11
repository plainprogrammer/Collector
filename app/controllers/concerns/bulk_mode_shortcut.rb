# What a refusal page's "Move them in bulk mode" button does, once for every kind of place a collector can empty: start the
# session's bulk selection under a location filter with every matching lot selected, and go to the bulk table under it
# (spec 059 decisions 1 and 3 for a place; spec 067 for a deck). It is the sequence spec 041 decision 5 described (filter,
# Edit many, select every matching lot) in one POST. The including controller finds the thing in the path through
# `Current.account` first (a 404 there ends the request before anything is stored) and passes only the filter string, so no
# request parameter is ever read here.
#
# @see file:collection-and-lots.md
module BulkModeShortcut
  extend ActiveSupport::Concern

  private
    # Replaces the session's stored selection, as Edit many does, and answers 303 to the bulk table.
    #
    # @param location_filter [String] the location filter's canonical string, `"<id>"` or `"deck:<id>"` (spec 037 decision 1;
    #   spec 065 decision 4), built by the caller from a record it found through the account
    # @return [void]
    def open_in_bulk_mode(location_filter)
      sort = CollectionTable::Sort.parse(nil, nil)
      BulkSelection.for(Current.session).restart!(query: "", sort:, location: location_filter, all: true)
      redirect_to helpers.collection_listing_path(bulk: 1, location: location_filter, sort:), status: :see_other
    end
end
