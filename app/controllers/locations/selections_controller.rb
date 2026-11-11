# The place refusal page's shortcut into bulk mode (spec 059, #187): a form button because Edit many is never a link
# (spec 006 FR-1). The place in the path is the only parameter read; what pressing does is `BulkModeShortcut`'s, which a
# deck's refusal page shares (`Decks::SelectionsController`, spec 067).
#
# @see file:collection-and-lots.md
class Locations::SelectionsController < ApplicationController
  include BulkModeShortcut

  # 404 for a location that isn't one of the account's places (spec 059 AC-4.1; a deck or a zone is not one, spec 062 AC-3.8).
  def create
    open_in_bulk_mode(Current.account.locations.places.find(params[:location_id]).id.to_s)
  end
end
