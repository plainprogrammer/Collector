# Builds the collection page in its views (spec 004 Story 11, spec 006): the grid, the table, or the
# table in bulk mode. The page uses it, and so do refused actions that re-render a collection URL (FR-5).
module CollectionListing
  extend ActiveSupport::Concern

  private
    def prepare_collection(query:, sort:, page:, view:, bulk:, path: request.fullpath)
      @bulk, @sort, @listing_path = bulk, sort, path
      @view = bulk ? "table" : view
      @listing = if @view == "table"
        CollectionTable.new(account: Current.account, query:, page:, sort:)
      else
        CollectionGrid.new(account: Current.account, query:, page:)
      end
      @selection_state = CollectionTable::SelectionState.new(table: @listing, selection: Current.session.bulk_selection) if bulk
    end

    # The page a collection URL names, e.g. the bulk table to re-render with a refusal.
    def prepare_collection_at(path)
      values = Rack::Utils.parse_query(URI.parse(path).query)
      prepare_collection(query: values["q"], sort: CollectionTable::Sort.parse(values["sort"], values["dir"]), page: values["page"],
        view: values["view"].presence_in(User::COLLECTION_VIEWS) || Current.user.collection_view, bulk: values["bulk"] == "1", path:)
    end

    def render_collection_refusal(message)
      flash.now[:alert] = message
      render "collections/show", status: :unprocessable_content
    end
end
