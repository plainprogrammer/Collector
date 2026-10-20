# Spec 025: a collector uploads an export file and sees what applying it would do. Spec 028 (decisions 1, 10): a file that
# can be applied and has something to change is kept for an hour, so that it can be applied with one click.
class Collections::ImportPreviewsController < ApplicationController
  def new
    no_store
  end

  def create
    no_store
    file = params[:export_file]
    @import = CollectionImport.new(account: Current.account, file:)
    return render(:new, status: :unprocessable_content) if @import.refused?

    @unloaded_catalogs = @import.unloaded_catalog_titles
    @catalogs_named = Catalog.sources.many?
    @upload = keep(file) if @import.applicable? && !@import.plan.nothing_to_change?
    render :show
  end

  private
    def keep(file)
      file.rewind # reads the upload a second time; spec 028 Phase 11 measures the preview's memory with it
      ImportUpload.store!(account: Current.account, bytes: file.read, plan: @import.plan)
    rescue ActiveStorage::Error, SystemCallError, ActiveRecord::ActiveRecordError => error
      Rails.logger.error("The previewed import file was not kept: #{error.class}")
      @store_failed = true
      nil
    end
end
