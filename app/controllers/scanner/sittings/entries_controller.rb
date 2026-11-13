# Adds the scanned card: one copy of the chosen printing and finish, at most once per reading (spec 009 Story 1). Every
# answer is a Turbo Stream (AC-1.3); an add returns the shell to the camera with the after-add line (spec 082 decision 12).
class Scanner::Sittings::EntriesController < ApplicationController
  include ScannerSitting

  NOT_ADDED = "That card couldn't be added. Scan it again.".freeze
  REPLAYED = {
    undone: "You added this card, then undid it. Scan it again to add it.",
    changed: "You added this card, and it has since changed in your collection."
  }.freeze

  def create
    attributes = params.expect(entry: %i[printing finish reading_key])
    printing = Catalog::Entry.includes(:set).find_by(external_key: attributes[:printing].to_s)
    entry = Scanner::Sitting.add!(account: Current.account, printing:, finish: attributes[:finish], reading_key: attributes[:reading_key]).entry
    render turbo_stream: [ turbo_stream.update("scanner_result", ""), *answer_for(entry), *sitting_redraw ]
  rescue Scanner::Sitting::Refused
    refuse NOT_ADDED
  rescue ActiveRecord::RecordInvalid
    refuse Catalog::QuickAddsController::FULL_LOT
  end

  private
    # An add empties the pane and the status line and says so on the after-add line, focus on the main button; a replay of an
    # undone or changed entry keeps the pane open with its sentence and no add button (spec 009 AC-1.5; spec 082 AC-4.8).
    def answer_for(entry)
      return [ say_in("status", REPLAYED.fetch(entry.state), alert: true) ] unless entry.state == :added

      [ turbo_stream.update("status", ""), turbo_stream.update("scanner_status_text", ""),
        *added_line(helpers.scanner_added(entry.printing, entry.finish), entry:, focus: :main) ]
    end

    def refuse(message)
      render turbo_stream: say_in("status", message, alert: true), status: :unprocessable_content
    end
end
