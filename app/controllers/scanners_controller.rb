# The card scanner page (spec 007 Stories 1–4, spec 009): a live camera with the card guide, on-device OCR, the candidate
# printings with their add buttons, and the account's open sitting.
class ScannersController < ApplicationController
  include ScannerPage
  include ScannerSitting

  def show
    @sitting = sitting_locals(current_sitting)
    @line = scanner_line
    @unloaded_catalogs = Catalog.unloaded_titles
    @catalogs_named = Catalog.sources.many?
  end

  private
    # What the after-add line shows on a page load (spec 082 decision 10): the end of a sitting's summary with a link to the
    # collection (spec 009 AC-3.5), or a flash from a page the scanner was left for (Edit copy), with its Undo; else nothing.
    def scanner_line
      if (count = flash[:sitting_summary])
        { message: "Added #{helpers.pluralize(count, "card")} in this sitting.", link: [ "Open your collection", collection_path ] }
      elsif (message = flash[:alert] || flash[:notice])
        { message:, alert: flash[:alert].present?, removal_undo: (flash[:undo] unless flash[:alert]) }
      end
    end
end
