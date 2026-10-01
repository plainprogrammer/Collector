# The desktop replay of a measured run (spec 007 AC-5.6): reads the stored strips again with the page's own
# recognition code in a local headless browser, and stores what it read under a label.
class Scanner::Measurements::ReplaysController < ApplicationController
  include MeasurementMode
  include ScannerPage
  allow_unauthenticated_access
  before_action :require_local_request

  LABEL = /\A[\w-]{1,40}\z/

  def show
    @label = params.expect(:label)
    return head(:not_found) unless @label.match?(LABEL)

    @files = measurement_run.measured_rows.map(&:file)
  end

  def create
    label = params.expect(:label)
    return head(:not_found) unless label.match?(LABEL)

    measurement_run.record_replay!(label, params.expect(results: [ %i[file name_text collector_text] ]).map(&:to_h))
    head :no_content
  end
end
