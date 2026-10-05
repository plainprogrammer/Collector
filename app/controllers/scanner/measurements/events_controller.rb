# Records what the collector did with a measured reading (spec 009 AC-9.2): an add with the candidate's rank (or "other"),
# an Undo, or opening a copy's details, against the manifest row whose capture carried the reading key. Development only.
class Scanner::Measurements::EventsController < ApplicationController
  include MeasurementMode

  def create
    event = params.expect(event: %i[kind rank reading_key])
    row = measurement_run.row_for_key(event[:reading_key].to_s)
    return head(:not_found) unless row && Scanner::MeasurementRun::EVENT_KINDS.include?(event[:kind])

    measurement_run.record_event!(row, kind: event[:kind], rank: event[:rank].presence, reading_key: event[:reading_key])
    head :no_content
  end
end
