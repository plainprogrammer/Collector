# Development-only measurement mode for the card scanner (spec 007 AC-5.1, FR-6): every action answers 404
# unless config.x.scanner_measurement is set (development's default; specs switch it on).
module MeasurementMode
  extend ActiveSupport::Concern

  included do
    before_action :require_measurement_mode
    rescue_from Scanner::MeasurementRun::ManifestError, with: -> { head :unprocessable_content }
  end

  private
    def require_measurement_mode
      head :not_found unless Scanner::MeasurementRun.enabled?
    end

    # The desktop replay is driven by a local headless browser that isn't signed in.
    def require_local_request
      head :not_found unless request.local?
    end

    def measurement_run = @measurement_run ||= Scanner::MeasurementRun.current

    def panel_locals(notice: nil, alert: false)
      next_row = measurement_run.next_row
      { run: measurement_run, next_row:, expected: next_row && measurement_run.expected_name(next_row),
        keep_frames: Scanner::MeasurementRun.keep_frames?, notice:, alert: }
    end

    def render_panel(notice, alert: false, status: :ok)
      render turbo_stream: turbo_stream.replace("measurement_panel", partial: "scanner/measurements/panel",
        locals: panel_locals(notice:, alert:)), status:
    end
end
