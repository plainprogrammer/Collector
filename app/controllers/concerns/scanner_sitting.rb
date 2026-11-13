# The account's open scanner sitting as the scanner shows it (spec 009 Story 3): the sitting and its kept entries,
# newest first, loaded in the controller and handed to the partials; and the streams that redraw it after a change, into the
# regions spec 082 decision 10 names. The account's places and deck zones come along for the sitting's place (spec 040
# decision 3, spec 065), loaded once per request.
module ScannerSitting
  extend ActiveSupport::Concern

  private
    # The open sitting for a page render, less one with no entries at all and no place, which says nothing and is dropped
    # (spec 040 AC-3.2): what a removed location leaves of a sitting opened only by choosing it.
    def current_sitting
      sitting = Current.account.scanner_sitting
      sitting unless sitting&.drop_if_pointless! # the has_one reader keeps a destroyed target, so the page is given nil
    end

    # The locals of the sitting partials. The sitting's location is handed over from the one read of the account's choices, so
    # naming a zone ("Deck › Zone") costs no further query (spec 065 decision 1); a location that is gone gives nil, which marks
    # the association loaded and reading nil: right, since the foreign key already nulled the column.
    def sitting_locals(sitting = Current.account.scanner_sitting)
      sitting.association(:location).target = account_choices.find(sitting.location_id) if sitting&.location_id
      { sitting:, entries: sitting ? sitting.kept_entries.to_a : [], conditions: scanner_conditions, choices: account_choices,
        added_any: sitting.present? && sitting.entries.exists? }
    end

    # The scale of the collectible the scanner reads (spec 042 decision 5): condition key => [ long label, short label ]. The one
    # place the scanner's controllers name that type for the sitting's choices; the model and the views are handed what they need.
    def scanner_conditions = Catalog.collecting_for(MTG::Reading::COLLECTIBLE_TYPE).conditions

    # What the sitting's Location select offers, read once per request (spec 065 decision 8): the account's places and zones.
    # A sitting's adds go to one of them or to none, never to a deck's own row.
    def account_choices = @account_choices ||= Location::Choices.new(Current.account)

    # The streams that redraw what shows the sitting (spec 082 decisions 7 to 9): the list's entries, the list sheet's title, the
    # top bar's destination and Done, the count. `focus` (:heading after an Undo) is where focus goes once the entries connect
    # (spec 047 decision 2; spec 082 decision 15). Texts go through html_escape: a stream's string is used as HTML.
    def sitting_redraw(focus: nil)
      locals = sitting_locals
      [ turbo_stream.replace("scanner_sitting", partial: "scanners/sitting", locals: locals.slice(:sitting, :entries, :conditions, :added_any).merge(focus:)),
        turbo_stream.update("scanner-sitting-heading", ERB::Util.html_escape(helpers.sitting_title(locals[:sitting], locals[:entries], locals[:conditions]))),
        turbo_stream.replace("scanner_sitting_bar", partial: "scanners/sitting_bar", locals: locals.slice(:sitting, :conditions)),
        turbo_stream.replace("scanner_count", partial: "scanners/count", locals: { count: locals[:entries].size }) ]
    end

    # The destination sheet's form, redrawn after a "Set" with focus back on "Set" (spec 047 decision 2).
    def picker_redraw(focus: :set)
      sitting = Current.account.scanner_sitting
      turbo_stream.replace("scanner_picker", partial: "scanners/picker",
        locals: { condition: sitting&.condition, location_id: sitting&.location_id, conditions: scanner_conditions, choices: account_choices, focus: })
    end

    # A sentence in one of the page's live regions (spec 082 decision 10's table): never empty, so every redraw is announced
    # (spec 047 FR-1).
    def say_in(region, message, alert: false)
      turbo_stream.update(region, partial: "shared/status_message", locals: { message:, alert: })
    end

    # The after-add line's sentence and its action: Undo for `entry`, or nothing (spec 082 decision 12).
    def added_line(message, entry: nil, focus: nil)
      [ turbo_stream.update("scanner_added_text", ERB::Util.html_escape(message)),
        turbo_stream.replace("scanner_added_action", partial: "scanners/added_action", locals: { entry:, focus: }) ]
    end
end
