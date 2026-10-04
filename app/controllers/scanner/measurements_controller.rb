# The card scanner in measurement mode (spec 007 Story 5): the manifest row to capture next, above the
# normal scanner.
class Scanner::MeasurementsController < ApplicationController
  include MeasurementMode
  include ScannerPage
  include ScannerSitting

  def show
    @sitting = sitting_locals
    @panel = panel_locals
  rescue Scanner::MeasurementRun::ManifestError => error
    @manifest_problem = error.message
  end
end
