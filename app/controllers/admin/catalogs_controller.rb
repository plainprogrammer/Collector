# The admin catalog page (spec 015 Stories 1 to 5): a panel per catalog type with its health, what can be started for it
# and how that is going. It names no collectible: everything comes from Catalog::Health and its operations.
class Admin::CatalogsController < ApplicationController
  include AdminOnly

  def show
    @catalogs = Catalog::Health.all
  end
end
