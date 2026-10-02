# Stores one measured capture: the strip text and images for the manifest row chosen before the shutter
# (spec 007 AC-5.3, AC-5.4).
class Scanner::Measurements::CapturesController < ApplicationController
  include MeasurementMode

  def create
    capture = params.expect(capture: %i[file name_text collector_text ms user_agent name_strip collector_strip])
    row = measurement_run.row(capture[:file])
    return head(:not_found) unless row

    kind = measurement_run.record!(row, name_text: capture[:name_text].to_s, collector_text: capture[:collector_text].to_s,
      ms: capture[:ms].to_i, user_agent: capture[:user_agent].to_s, name_strip: capture[:name_strip], collector_strip: capture[:collector_strip])
    render_panel "Stored #{row.file} as #{kind == :measured ? "the measured capture" : "a retake"}."
  rescue Scanner::MeasurementRun::InvalidCapture => error
    render_panel error.message, alert: true, status: :unprocessable_content
  end
end
