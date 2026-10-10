class MoresController < ApplicationController
  def show
    # Only admins can act on an unloaded catalog from here (spec 015 AC-1.1); members see the notice where they search.
    @unloaded_catalogs = Current.user.admin? ? Catalog.unloaded_titles : []
    @catalogs_named = Catalog.sources.many?
  end
end
