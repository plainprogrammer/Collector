# Builds the collection page in its views (spec 004 Story 11, spec 006): the grid or the table.
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
    end
end
