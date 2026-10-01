# The collection page (spec 004 Story 11, spec 006): the grid or the table, by the URL's view or the
# collector's saved one.
class CollectionsController < ApplicationController
  include CollectionListing

  def root
    redirect_to collection_path
  end

  def show
    remember_view
    prepare_collection(query: params[:q], sort: CollectionTable::Sort.parse(params[:sort], params[:dir]), page: params[:page],
      view: requested_view || Current.user.collection_view, bulk: false)
  end

  private
    def requested_view = params[:view].presence_in(User::COLLECTION_VIEWS)

    # A page naming a view saves it as the collector's choice (spec 006 AC-1.3), unless the browser
    # only prefetched it: nobody chose that (AC-1.10, FR-1).
    def remember_view
      return if requested_view.nil? || prefetch? || Current.user.collection_view == requested_view

      Current.user.update!(collection_view: requested_view)
    end

    def prefetch?
      [ request.headers["Sec-Purpose"], request.headers["X-Sec-Purpose"] ].compact.any? { |purpose| purpose.include?("prefetch") }
    end
end
