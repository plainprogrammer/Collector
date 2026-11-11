# Bulk mode's selection (spec 006 Stories 4–5, FR-4). Edit many starts an empty one. The bulk form
# records a page's ticks and then goes where the pressed control says: Done, the filter, a page or
# sort, or an action's page. Nothing here answers a GET, so a prefetch can't change a selection.
class Collections::SelectionsController < ApplicationController
  include CollectionListing

  ACTIONS = %w[set_condition move remove].freeze

  def create
    query = CollectionFilter.normalize(params[:q])
    location = CollectionFilter::Place.parse(params[:location])
    sort = CollectionTable::Sort.parse(params[:sort], params[:dir])
    BulkSelection.for(Current.session).restart!(query:, sort:, location:)
    redirect_to helpers.collection_listing_path(bulk: 1, query:, location:, sort:), status: :see_other
  end

  # The rendered name filter and location are the page's context; only Filter applies what the fields now show (spec 037
  # decision 5). The location stays the canonical string submitted, never re-resolved, so a removed one selects nothing
  # (decision 7).
  def update
    query = CollectionFilter.normalize(params[:rendered_q])
    location = CollectionFilter::Place.parse(params[:rendered_location])
    sort = CollectionTable::Sort.parse(params[:sort], params[:dir])
    selection = BulkSelection.for(Current.session)
    return done(selection, query, location, sort) if params[:go] == "done"

    selection.restart!(query:, sort:, location:) unless selection.context?(query, sort, location:)
    selection.record!(shown_ids: ids(:shown_ids), ticked_ids: ids(:ticked_ids), baseline_ids: ids(:baseline_ids),
      header_rendered: params[:all_rendered] == "1", header_ticked: params[:all] == "1", header_toggled: params[:header_toggled] == "1")
    ACTIONS.include?(params[:go]) && offered?(params[:go]) ? act(selection, query, location, sort) : navigate(selection, *destination(query, location, sort))
  end

  private
    # Lot ids from the form; anything that isn't a list of id strings counts as none, and so does a blank entry.
    def ids(key) = Array(params[key]).grep(/\A\d+\z/).map(&:to_i)

    # Back to the saved view with the same filter and sort; the ticks are discarded (AC-4.5).
    def done(selection, query, location, sort)
      selection.destroy!
      redirect_to helpers.collection_listing_path(query:, location:, sort:), status: :see_other
    end

    # "Move to…" is offered only while the account has a place or a zone; asked for without one it is a navigation (spec 041
    # AC-1.2; spec 065 decision 3).
    def offered?(action) = action != "move" || Location::Choices.new(Current.account).any?

    def act(selection, query, location, sort)
      page = params[:page].presence
      if selection.lots.exists?
        path = case params[:go]
        when "remove" then new_collection_bulk_removal_path(page:)
        when "move" then new_collection_move_path(page:)
        else new_collection_condition_change_path(page:)
        end
        redirect_to path, status: :see_other
      else
        prepare_collection_at(helpers.collection_listing_path(bulk: 1, query:, location:, sort:, page:))
        gone = ids(:ticked_ids).any? || params[:all] == "1"
        render_collection_refusal(gone ? BulkSelection::NONE_LEFT : BulkSelection::NOTHING_SELECTED)
      end
    end

    def navigate(selection, query, location, sort, page)
      selection.restart!(query:, sort:, location:) unless selection.context?(query, sort, location:)
      redirect_to helpers.collection_listing_path(bulk: 1, query:, location:, sort:, page:), status: :see_other
    end

    # Where the filter (the form's default submit), a sort header or a pager button leads (FR-4).
    # Unchanged filters reload the same page (spec 037 decision 5).
    def destination(query, location, sort)
      if params[:go] == "filter"
        filter = CollectionFilter.normalize(params[:q])
        place = CollectionFilter::Place.parse(params[:location])
        [ filter, place, sort, (params[:page] if filter == query && place == location) ]
      elsif (values = collection_values(params[:go]))
        [ CollectionFilter.normalize(values["q"]), CollectionFilter::Place.parse(values["location"]),
          CollectionTable::Sort.parse(values["sort"], values["dir"]), values["page"] ]
      else
        [ query, location, sort, params[:page] ]
      end
    end

    # The params of a collection URL on this instance; nil for anything else.
    def collection_values(url)
      uri = URI.parse(url_from(url).to_s)
      Rack::Utils.parse_query(uri.query) if uri.path == collection_path
    rescue URI::InvalidURIError
      nil
    end
end
