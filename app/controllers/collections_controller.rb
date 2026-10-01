# The collection page (spec 004 Story 11, spec 006): the grid or the table, by the URL's view or the
# collector's saved one, or the table in bulk mode.
class CollectionsController < ApplicationController
  include CollectionListing

  def root
    redirect_to collection_path
  end

  def show
    bulk = params[:bulk] == "1"
    remember_view unless bulk
    prepare_collection(query: params[:q], sort: CollectionTable::Sort.parse(params[:sort], params[:dir]), page: params[:page],
      view: requested_view || Current.user.collection_view, bulk:)
  end

  private
    def requested_view = params[:view].presence_in(User::COLLECTION_VIEWS)

    # A page naming a view saves it as the collector's choice (spec 006 AC-1.3), unless the browser
    # only prefetched it: nobody chose that (AC-1.10, FR-1). Bulk mode never saves one (AC-4.5).
    def remember_view
      return if requested_view.nil? || prefetch? || Current.user.collection_view == requested_view

      Current.user.update!(collection_view: requested_view)
    end

    def prefetch?
      %w[Sec-Purpose X-Sec-Purpose X-Moz Purpose].any? { |header| request.headers[header].to_s.include?("prefetch") }
    end
end
