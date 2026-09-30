# Where the collector came from (spec 004 AC-8.9, FR-13): collection links carry from=collection;
# everything else is Search. Return paths are followed only when they're on this instance (AC-7.3).
module CardContext
  extend ActiveSupport::Concern

  included { helper_method :card_context, :card_params }

  private
    def card_context = params[:from] == "collection" ? :collection : :search

    def card_params = card_context == :collection ? { from: "collection" } : {}

    def safe_return_to(fallback) = url_from(params[:return_to]) || fallback
end
