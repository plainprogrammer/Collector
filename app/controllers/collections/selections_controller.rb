# Bulk mode's selection (spec 006 Stories 4–5, FR-4). Edit many starts an empty one. The bulk form
# records a page's ticks and then goes where the pressed control says: Done, the filter, a page or
# sort, or an action's page. Nothing here answers a GET, so a prefetch can't change a selection.
class Collections::SelectionsController < ApplicationController
  include CollectionListing

  ACTIONS = %w[set_condition remove].freeze

  def create
    query = CollectionFilter.normalize(params[:q])
    sort = CollectionTable::Sort.parse(params[:sort], params[:dir])
    BulkSelection.for(Current.session).restart!(query:, sort:)
    redirect_to helpers.collection_listing_path(bulk: 1, query:, sort:), status: :see_other
  end

  def update
    query = CollectionFilter.normalize(params[:rendered_q])
    sort = CollectionTable::Sort.parse(params[:sort], params[:dir])
    selection = BulkSelection.for(Current.session)
    return done(selection, query, sort) if params[:go] == "done"

    selection.restart!(query:, sort:) unless selection.context?(query, sort)
    selection.record!(shown_ids: ids(:shown_ids), ticked_ids: ids(:ticked_ids),
      header_rendered: params[:all_rendered] == "1", header_ticked: params[:all] == "1")
    ACTIONS.include?(params[:go]) ? act(selection, query, sort) : navigate(selection, *destination(query, sort))
  end

  private
    # Lot ids from the form; anything that isn't a list of id strings counts as none, and so does a blank entry.
    def ids(key) = Array(params[key]).grep(/\A\d+\z/).map(&:to_i)

    # Back to the saved view with the same filter and sort; the ticks are discarded (AC-4.5).
    def done(selection, query, sort)
      selection.destroy!
      redirect_to helpers.collection_listing_path(query:, sort:), status: :see_other
    end

    def act(selection, query, sort)
      page = params[:page].presence
      if selection.lots.exists?
        path = params[:go] == "remove" ? new_collection_bulk_removal_path(page:) : new_collection_condition_change_path(page:)
        redirect_to path, status: :see_other
      else
        prepare_collection_at(helpers.collection_listing_path(bulk: 1, query:, sort:, page:))
        gone = ids(:ticked_ids).any? || params[:all] == "1"
        render_collection_refusal(gone ? BulkSelection::NONE_LEFT : BulkSelection::NOTHING_SELECTED)
      end
    end

    def navigate(selection, query, sort, page)
      selection.restart!(query:, sort:) unless selection.context?(query, sort)
      redirect_to helpers.collection_listing_path(bulk: 1, query:, sort:, page:), status: :see_other
    end

    # Where the filter (the form's default submit), a sort header or a pager button leads (FR-4).
    # An unchanged filter reloads the same page.
    def destination(query, sort)
      if params[:go] == "filter"
        filter = CollectionFilter.normalize(params[:q])
        [ filter, sort, (params[:page] if filter == query) ]
      elsif (values = collection_values(params[:go]))
        [ CollectionFilter.normalize(values["q"]), CollectionTable::Sort.parse(values["sort"], values["dir"]), values["page"] ]
      else
        [ query, sort, params[:page] ]
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
