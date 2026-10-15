# Undoes one line of number entry: its copies leave the lot they went into (spec 026 decision 5, Story 3). An undone
# line has left the list; it, another account's line, or one of a list that Done cleared, is not found (AC-3.8).
class Collections::NumberEntries::Lines::UndosController < ApplicationController
  include NumberEntryPage

  GONE = "That line is no longer in your list.".freeze
  CHANGED = "Those copies have changed in your collection, so they can't be undone here.".freeze

  def create
    line = Current.account.number_entry&.lines&.kept&.includes(:entry)&.find_by(id: params[:line_id])
    return refuse(GONE, status: :not_found) unless line

    # A removed lot can't come back through a bulk removal's Undo any more, as with the scanner's Undo (spec 009).
    BulkRemoval.supersede!(Current.session) if line.undo!
    redirect_to page_path, status: :see_other, notice: "Undid #{line.quantity} × #{line.entry.name}."
  rescue NumberEntry::Line::NotUndoable
    refuse(CHANGED, status: :unprocessable_content)
  end

  private
    def refuse(message, status:)
      flash.now[:alert] = message
      render_page(status:)
    end
end
