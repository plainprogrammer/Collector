# Stores one measured capture: the strip text and images for the manifest row chosen before the shutter
# (spec 007 AC-5.3, AC-5.4).
class Scanner::Measurements::CapturesController < ApplicationController
  include MeasurementMode

  def create
    capture = params.expect(capture: %i[file name_text collector_text ms user_agent name_strip collector_strip reading_key outline detect_ms warp_ms
      art_ms art_download_ms art_ready_ms ready_ms frame guide])
    row = measurement_run.row(capture[:file])
    return head(:not_found) unless row

    extra = { "reading_key" => capture[:reading_key].to_s[Scanner::Sitting::KEY_FORMAT], "outline" => capture[:outline].to_s[/\A(live|found|not_found)\z/],
              **%i[detect_ms warp_ms art_ms art_download_ms art_ready_ms ready_ms].to_h { [ it.to_s, capture[it].presence&.to_i ] } }
    kind = measurement_run.record!(row, name_text: capture[:name_text].to_s, collector_text: capture[:collector_text].to_s,
      ms: capture[:ms].to_i, user_agent: capture[:user_agent].to_s, name_strip: capture[:name_strip], collector_strip: capture[:collector_strip], extra:,
      **frame_params(capture))
    render_panel "Stored #{row.file} as #{kind == :measured ? "the measured capture" : "a retake"}."
  rescue Scanner::MeasurementRun::InvalidCapture => error
    render_panel error.message, alert: true, status: :unprocessable_content
  end

  private
    # Spec 010: the live frame and its guide rect, kept only when the measurement config says so.
    def frame_params(capture)
      return {} unless Scanner::MeasurementRun.keep_frames? && capture[:frame]

      { frame: capture[:frame], guide: parsed_guide(capture[:guide]) }
    end

    def parsed_guide(text)
      JSON.parse(text.to_s)
    rescue JSON::ParserError
      nil # record! refuses a frame without a whole guide rect
    end
end
