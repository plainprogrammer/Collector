# The session's bulk selection, for the pages that act on it (spec 006 Stories 6–7). Their Cancel,
# Back and redirects return to the bulk table it was made in, on the same page (AC-6.5, AC-7.2, AC-7.9).
module BulkSelected
  extend ActiveSupport::Concern

  included do
    before_action :set_selection
  end

  private
    def set_selection
      @selection = Current.session.bulk_selection
      @bulk_path = helpers.collection_listing_path(bulk: 1, query: @selection&.query, sort: @selection&.sort, page: params[:page])
      redirect_to @bulk_path, status: :see_other, alert: BulkSelection::NOTHING_SELECTED if request.get? && !selection?
    end

    def selection? = @selection.present? && @selection.lots.exists?
end
