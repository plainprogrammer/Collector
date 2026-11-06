# The card scanner page (spec 007 Stories 1–4, spec 009): a live camera with the card guide, on-device OCR, the candidate
# printings with their add buttons, and the account's open sitting.
class ScannersController < ApplicationController
  include ScannerPage
  include ScannerSitting

  def show
    @sitting = sitting_locals(current_sitting)
    @summary = flash[:sitting_summary]
    @unloaded_catalogs = Catalog.unloaded_titles
    @catalogs_named = Catalog.sources.many?
  end

  private
    # The open sitting, less one with no entries at all and no place, which says nothing and is dropped (spec 040 AC-3.2):
    # what a removed location leaves of a sitting opened only by choosing it.
    def current_sitting
      sitting = Current.account.scanner_sitting
      return sitting unless sitting&.pointless?

      sitting.destroy!
      nil # the has_one reader keeps its destroyed target, so the page is given none explicitly
    end
end
