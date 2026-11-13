# Undoes one add of the open sitting: its copy leaves the lot it went into (spec 009 Story 4). A Turbo Stream answer keeps
# the scanner on the page; another account's entry, or one of a sitting that has ended, is not found (AC-3.8).
class Scanner::Sittings::Entries::UndosController < ApplicationController
  include ScannerSitting

  REFUSED = {
    "undone" => "That card was already undone.",
    "changed" => "That copy has changed in your collection, so it can't be undone here."
  }.freeze

  def create
    entry = Current.account.scanner_sitting&.entries&.includes(printing: :set)&.find_by(id: params[:entry_id])
    return head(:not_found) unless entry

    copy = helpers.scanner_copy(entry.printing, entry.finish)
    BulkRemoval.supersede!(Current.session) if entry.undo!
    message = "Removed 1 × #{copy} from your collection."
    render turbo_stream: [ say_in("scanner_list_status", message), *added_line(message), *sitting_redraw(focus: :heading) ]
  rescue Scanner::SittingEntry::NotUndoable => error
    render turbo_stream: [ say_in("scanner_list_status", REFUSED.fetch(error.message), alert: true), *sitting_redraw(focus: :heading) ],
      status: :unprocessable_content
  end
end
