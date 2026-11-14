# Turns what was read off a card into what the page shows (spec 007 Story 3, spec 088 decisions 2 to 4, 11): a selection of the
# card's printings or of the candidate cards, or a sentence on the status line when nothing could be read or no card matches.
# Only the text, the page's reading key and a live capture's nearest artworks (ids and distances, spec 011 FR-5) arrive here; the
# photo and its fingerprint never leave the device.
class Scanner::ReadingsController < ApplicationController
  TOO_LONG = "That reading was too long to use. Line the card up with the guide and capture it again.".freeze
  NO_KEY = "That reading couldn't be used. Capture the card again.".freeze
  NOTHING_READ = "Nothing could be read. Line the card up with the guide and capture it again.".freeze
  NO_MATCH = "No card matches what was read. Line the card up with the guide and capture it again.".freeze
  CATALOG_NOT_READY = "The card catalog isn't ready yet. Once it has loaded, scan the card again.".freeze

  def create
    attributes = params.expect(reading: %i[name_text collector_text key])
    reading = MTG::Reading.new(attributes.slice(:name_text, :collector_text))
    reading.artworks = MTG::Art::Sent.from_params(params) # read leniently: never fails the request (spec 011 AC-6.1)
    key = attributes[:key].to_s
    if !Scanner::Sitting::KEY_FORMAT.match?(key) then refuse(NO_KEY)
    elsif reading.valid?
      render turbo_stream: answer(reading.resolve, key)
      record_measurement(key, reading)
    else refuse(TOO_LONG)
    end
  end

  private
    # The streams that answer a resolved reading. A refusal that opens the pane is a visible alert in its region and leaves
    # `#scanner_result` empty; nothing read or no match is the status line's sentence and opens no pane (spec 088 decision 11).
    def answer(reading, key)
      if !reading.catalog_ready? then [ alert_in_pane(CATALOG_NOT_READY) ]
      elsif reading.candidates.empty?
        [ turbo_stream.update("scanner_status_text", ERB::Util.html_escape(reading.nothing_read? ? NOTHING_READ : NO_MATCH)) ]
      else
        [ turbo_stream.update("scanner_result", partial: "scanners/selection", locals: { selection: Scanner::Selection.for_reading(reading, key:) }) ]
      end
    end

    # Development measurement mode only (spec 011 AC-9.3): never fails or changes the answer.
    def record_measurement(key, reading)
      Scanner::MeasurementRun.current(framing: Scanner::MeasurementRun.framing_in(session))&.record_reading!(key, reading)
    rescue StandardError => error
      Rails.logger.warn("scanner.measurement reading not recorded: #{error.class}: #{error.message}")
    end

    def alert_in_pane(message)
      turbo_stream.update("status", partial: "shared/status_message", locals: { message:, alert: true })
    end

    def refuse(message)
      render turbo_stream: alert_in_pane(message), status: :unprocessable_content
    end
end
