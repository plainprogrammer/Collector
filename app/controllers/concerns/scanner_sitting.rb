# The account's open scanner sitting as the scanner shows it (spec 009 Story 3): the sitting and its kept entries,
# newest first, loaded in the controller and handed to the partials; and the streams that redraw it after a change. The
# account's locations come along for the sitting's place (spec 040 decision 3), loaded once per request.
module ScannerSitting
  extend ActiveSupport::Concern

  private
    # The open sitting for a page render, less one with no entries at all and no place, which says nothing and is dropped
    # (spec 040 AC-3.2): what a removed location leaves of a sitting opened only by choosing it.
    def current_sitting
      sitting = Current.account.scanner_sitting
      sitting unless sitting&.drop_if_pointless! # the has_one reader keeps a destroyed target, so the page is given nil
    end

    def sitting_locals(sitting = Current.account.scanner_sitting)
      { sitting:, entries: sitting ? sitting.kept_entries.to_a : [], conditions: scanner_conditions, locations: account_locations,
        added_any: sitting.present? && sitting.entries.exists? }
    end

    # The scale of the collectible the scanner reads (spec 042 decision 5): condition key => [ long label, short label ]. The one
    # place the scanner's controllers name that type for the sitting's choices; the model and the views are handed what they need.
    def scanner_conditions = Catalog.collecting_for(MTG::Reading::COLLECTIBLE_TYPE).conditions

    # The account's locations in the order of the locations page, loaded once per request.
    def account_locations = @account_locations ||= Current.account.locations.ordered.to_a

    # Redraws the panel (after an add, an Undo or a change of place, spec 040 FR-1) and says what happened; a nil message
    # clears the status line.
    def sitting_stream(message, alert: false)
      status = message ? turbo_stream.update("status", partial: "shared/status_message", locals: { message:, alert: }) : turbo_stream.update("status", "")
      [ turbo_stream.replace("scanner_sitting", partial: "scanners/sitting", locals: sitting_locals), status ]
    end
end
