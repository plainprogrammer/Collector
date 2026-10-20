# Spec 028: applies the signed-in collector's stored upload. Nothing in the request names an account, an upload or a lot.
class Collections::ImportsController < ApplicationController
  PREVIEW_AGAIN = "Preview the file again.".freeze

  def create
    no_store
    result = CollectionImport::Apply.new(account: Current.account, fingerprint: params[:fingerprint], confirmed: params[:confirm_removal] == "1").call
    respond_to_result(result)
  rescue StandardError => error
    Rails.logger.error("Applying an import failed: #{error.class}")
    render :failed, status: :internal_server_error
  end

  private
    def respond_to_result(result)
      case result.outcome
      when :applied then redirect_to collection_path, notice: notice_for(result.plan.counts), status: :see_other
      when :missing, :unreadable then upload_page(PREVIEW_AGAIN)
      when :expired then upload_page("Your preview has expired. Choose the file again.")
      when :refused then refused(result.import)
      when :nothing_to_change then preview(result, "This file has nothing to change", :unprocessable_content, upload: nil)
      when :stale then preview(result, "The collection or the file changed since you looked. This is what applying would do now.", :conflict)
      when :unconfirmed then preview(result, "Confirm the removal to apply this file", :unprocessable_content)
      end
    end

    def notice_for(counts)
      "Imported: #{helpers.pluralize(counts[:added], "lot")} added, #{counts[:changed]} changed, #{counts[:removed]} removed"
    end

    def upload_page(message)
      flash.now[:alert] = message
      render "collections/import_previews/new", status: :unprocessable_content
    end

    def refused(import)
      @import = import
      return render("collections/import_previews/new", status: :unprocessable_content) if @import.refused?

      render_preview(import, nil, :unprocessable_content)
    end

    def preview(result, message, status, upload: result.upload)
      flash.now[:alert] = message
      render_preview(result.import, upload, status)
    end

    def render_preview(import, upload, status)
      @import = import
      @upload = upload
      @unloaded_catalogs = import.unloaded_catalog_titles
      @catalogs_named = Catalog.sources.many?
      render "collections/import_previews/show", status:
    end
end
