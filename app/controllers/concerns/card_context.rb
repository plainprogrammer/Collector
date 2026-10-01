# Where the collector came from (spec 004 AC-8.9, FR-13): collection links carry from=collection;
# everything else is Search. Return paths are followed only when they're on this instance (AC-7.3).
module CardContext
  extend ActiveSupport::Concern

  included { helper_method :card_context, :card_params, :lot_return_path, :lot_return_params }

  private
    def card_context = params[:from] == "collection" ? :collection : :search

    def card_params = card_context == :collection ? { from: "collection" } : {}

    def safe_return_to(fallback) = url_from(params[:return_to]) || fallback

    # Where a lot's edit and removal pages go back to: the collection table they came from (spec 006
    # AC-2.6), or the card page.
    def lot_return_path(entry) = safe_return_to(catalog_entry_path(entry, **card_params))

    # The return path, for a lot page's forms to carry on, when it's one to follow.
    def lot_return_params = url_from(params[:return_to]) ? { return_to: params[:return_to] } : {}
end
