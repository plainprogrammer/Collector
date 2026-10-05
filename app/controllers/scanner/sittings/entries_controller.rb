# Adds the scanned card: one copy of the chosen printing and finish, at most once per reading (spec 009 Story 1). Every
# answer is a Turbo Stream, so the scanner and its camera stay on the page (AC-1.3).
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
    added = Scanner::Sitting.add!(account: Current.account, printing:, finish: attributes[:finish], reading_key: attributes[:reading_key])
    render turbo_stream: [ result_stream(added.entry), *sitting_stream(message_for(added.entry), alert: added.entry.state != :added) ]
  rescue Scanner::Sitting::Refused
    refuse NOT_ADDED
  rescue ActiveRecord::RecordInvalid
    refuse Catalog::QuickAddsController::FULL_LOT
  end

  private
    def message_for(entry)
      return REPLAYED.fetch(entry.state) unless entry.state == :added

      "Added 1 × #{helpers.scanner_copy(entry.printing, entry.finish)} to your collection."
    end

    # The reading clears once its card is in (AC-1.3); a replay of an undone or changed add shows that instead, with no
    # add button (AC-1.5).
    def result_stream(entry)
      return turbo_stream.update("scanner_result", "") if entry.state == :added

      turbo_stream.update("scanner_result", partial: "shared/status_message", locals: { message: REPLAYED.fetch(entry.state), alert: true })
    end

    def refuse(message)
      render turbo_stream: turbo_stream.update("status", partial: "shared/status_message", locals: { message:, alert: true }),
        status: :unprocessable_content
    end
end
