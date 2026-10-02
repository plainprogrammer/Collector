# Turns the text read off a card into what the page shows (spec 007 Story 3). Only text arrives here; the
# photo never leaves the device (FR-3).
class Scanner::ReadingsController < ApplicationController
  TOO_LONG = "That reading was too long to use. Line the card up with the guide and capture it again.".freeze

  def create
    reading = MTG::Reading.new(params.expect(reading: %i[name_text collector_text]))
    if reading.valid?
      render turbo_stream: turbo_stream.update("scanner_result", partial: "scanners/result", locals: { reading: reading.resolve })
    else
      render turbo_stream: turbo_stream.update("scanner_result", partial: "shared/status_message", locals: { message: TOO_LONG, alert: true }),
        status: :unprocessable_content
    end
  end
end
