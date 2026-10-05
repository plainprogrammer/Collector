# The account's open scanner sitting as the scanner shows it (spec 009 Story 3): the sitting and its kept entries,
# newest first, loaded in the controller and handed to the partials; and the streams that redraw it after a change.
module ScannerSitting
  extend ActiveSupport::Concern

  private
    def sitting_locals(sitting = Current.account.scanner_sitting)
      { sitting:, entries: sitting ? sitting.kept_entries.to_a : [] }
    end

    def sitting_stream(message, alert: false)
      [ turbo_stream.replace("scanner_sitting", partial: "scanners/sitting", locals: sitting_locals),
        turbo_stream.update("status", partial: "shared/status_message", locals: { message:, alert: }) ]
    end
end
