# Turns what was read off a card into what the page shows (spec 007 Story 3): the candidates, each with an add button per
# finish for this reading (spec 009 Story 1). Only the text, the page's reading key and a live capture's nearest artworks
# (ids and distances, spec 011 FR-5) arrive here; the photo and its fingerprint never leave the device.
class Scanner::ReadingsController < ApplicationController
  TOO_LONG = "That reading was too long to use. Line the card up with the guide and capture it again.".freeze
  NO_KEY = "That reading couldn't be used. Capture the card again.".freeze

  def create
    attributes = params.expect(reading: %i[name_text collector_text key])
    reading = MTG::Reading.new(attributes.slice(:name_text, :collector_text))
    reading.artworks = MTG::Art::Sent.from_params(params) # read leniently: never fails the request (spec 011 AC-6.1)
    key = attributes[:key].to_s
    if !Scanner::Sitting::KEY_FORMAT.match?(key) then refuse(NO_KEY)
    elsif reading.valid?
      render turbo_stream: turbo_stream.update("scanner_result", partial: "scanners/result", locals: { reading: reading.resolve, key: })
      record_measurement(key, reading)
    else refuse(TOO_LONG)
    end
  end

  private
    # Development measurement mode only (spec 011 AC-9.3): never fails or changes the answer.
    def record_measurement(key, reading)
      Scanner::MeasurementRun.current&.record_reading!(key, reading)
    rescue StandardError => error
      Rails.logger.warn("scanner.measurement reading not recorded: #{error.class}: #{error.message}")
    end

    def refuse(message)
      render turbo_stream: turbo_stream.update("scanner_result", partial: "shared/status_message", locals: { message:, alert: true }),
        status: :unprocessable_content
    end
end
