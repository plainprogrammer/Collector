# Turns the text read off a card into what the page shows (spec 007 Story 3): the candidates, each with an add button per
# finish for this reading (spec 009 Story 1). Only the text and the page's reading key arrive here; the photo never leaves
# the device (spec 007 FR-3, spec 009 FR-5).
class Scanner::ReadingsController < ApplicationController
  TOO_LONG = "That reading was too long to use. Line the card up with the guide and capture it again.".freeze
  NO_KEY = "That reading couldn't be used. Capture the card again.".freeze

  def create
    attributes = params.expect(reading: %i[name_text collector_text key])
    reading = MTG::Reading.new(attributes.slice(:name_text, :collector_text))
    key = attributes[:key].to_s
    if !Scanner::Sitting::KEY_FORMAT.match?(key) then refuse(NO_KEY)
    elsif reading.valid?
      render turbo_stream: turbo_stream.update("scanner_result", partial: "scanners/result", locals: { reading: reading.resolve, key: })
    else refuse(TOO_LONG)
    end
  end

  private
    def refuse(message)
      render turbo_stream: turbo_stream.update("scanner_result", partial: "shared/status_message", locals: { message:, alert: true }),
        status: :unprocessable_content
    end
end
