# The card scanner page (spec 007 Stories 1–4): a live camera with the card guide, on-device OCR, and the
# candidate printings. Reachable by URL only until adding from the scanner ships (AC-1.7).
class ScannersController < ApplicationController
  include ScannerPage

  def show; end
end
