# Spec 025: a collector uploads an export file and sees what applying it would do. The file is read in the request
# and kept nowhere; nothing is written (decision 6).
class Collections::ImportPreviewsController < ApplicationController
  def new
    no_store
  end

  def create
    no_store
    @import = CollectionImport.new(account: Current.account, file: params[:export_file])
    return render(:new, status: :unprocessable_content) if @import.refused?

    @unloaded_catalogs = @import.unloaded_catalog_titles
    @catalogs_named = Catalog.sources.many?
    render :show
  end
end
