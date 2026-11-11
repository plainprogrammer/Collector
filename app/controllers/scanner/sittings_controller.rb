# Sets what the scanner sitting's adds get (spec 042 decisions 2, 8, 9; spec 040 Stories 1–4): a condition from the scanner's
# vocabulary, a place or a zone among the account's, or both, each or none cleared. The answer is a Turbo Stream that redraws
# the panel, so the camera and the reading on screen stay. Both values are checked before anything is written; a value that
# fails changes nothing, and the condition's message wins when both fail.
class Scanner::SittingsController < ApplicationController
  include ScannerSitting

  GONE = "That location isn't one of yours any more. Choose again.".freeze
  UNKNOWN_CONDITION = "That isn't a known condition. Choose again.".freeze

  def update
    attributes = params.expect(sitting: %i[condition location_id]) # a request with neither key (or no sitting) raises ParameterMissing: a 400

    choices = {}
    if attributes.key?(:condition)
      value = attributes[:condition].to_s
      return refuse(UNKNOWN_CONDITION) unless value.empty? || scanner_conditions.key?(value)

      choices[:condition] = value.presence
    end
    if attributes.key?(:location_id)
      value = attributes[:location_id].to_s
      # A place or a zone of the account (spec 065 decision 8); a deck's own row is not a place. The guard is ID_TEXT, so "12abc"
      # and "012" are refused, not cast to 12, and a longer id never reaches a SQLite bind.
      location = Current.account.locations.placeable.includes(:parent).find_by(id: value) if value.match?(Location::ID_TEXT)
      return refuse(GONE) if value.present? && location.nil?

      choices[:location] = location
    end

    render turbo_stream: sitting_stream(chosen_message(Scanner::Sitting.choose!(account: Current.account, **choices)), focus: :set)
  end

  private
    def refuse(message) = render(turbo_stream: sitting_stream(message, alert: true, focus: :set), status: :unprocessable_content)

    # Says what later adds get (spec 042 decision 3, spec 047 decision 1): both choices for an account with locations, the
    # condition alone otherwise. A sitting "Set" deleted, or none open, says the nothing-set sentence: a deleted sitting held
    # neither choice, and `choose!` returns nil when there was none to clear.
    def chosen_message(sitting)
      sitting = nil unless sitting&.persisted? # a destroyed sitting still holds what it had in memory
      parts = [ (sitting&.condition && scanner_conditions.dig(sitting.condition, 0)) || "condition not specified" ]
      parts << (sitting&.location ? "in #{sitting.location.label}" : "no location") if account_choices.any?
      "Cards you scan now: #{parts.join(", ")}."
    end
end
