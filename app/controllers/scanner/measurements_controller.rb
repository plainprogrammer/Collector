# The card scanner in measurement mode (spec 007 Story 5): the manifest row to capture next, in the
# one-screen scanner's own shell (its run button in the top bar, its run sheet beside the sitting's).
class Scanner::MeasurementsController < ApplicationController
  include MeasurementMode
  include ScannerPage
  include ScannerSitting

  def show
    @sitting = sitting_locals(current_sitting)
    @panel = panel_locals
  rescue Scanner::MeasurementRun::ManifestError => error
    @manifest_problem = error.message
  end
end
