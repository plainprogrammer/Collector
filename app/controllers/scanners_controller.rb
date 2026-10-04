# The card scanner page (spec 007 Stories 1–4, spec 009): a live camera with the card guide, on-device OCR, the candidate
# printings with their add buttons, and the account's open sitting.
class ScannersController < ApplicationController
  include ScannerPage
  include ScannerSitting

  def show
    @sitting = sitting_locals
    @summary = flash[:sitting_summary]
  end
end
