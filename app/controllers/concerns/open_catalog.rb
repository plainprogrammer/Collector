# Spec 023: with the operator's setting on (Catalog.public?), catalog pages answer visitors too. A visitor gets no
# tenant data (FR-3); views tell the two apart with collector? (FR-4). Signing in from a catalog page returns to it.
module OpenCatalog
  extend ActiveSupport::Concern

  included do
    allow_unauthenticated_access if: -> { Catalog.public? }
    before_action :resume_session
    after_action :remember_visited_page, unless: -> { Current.user }
  end

  private
    def owned_quantities(entry_ids) = Current.account ? Lot.owned_quantities(Current.account, entry_ids) : {}

    # The page a visitor saw, for sign-in to return to (decision 4); never a page the browser only prefetched. GET
    # only: a HEAD isn't a page someone saw (request_authentication also stores HEADs; harmless either way).
    def remember_visited_page
      return unless request.get? && !prefetch?

      session[:return_to_after_authenticating] = request.fullpath
    end
end
