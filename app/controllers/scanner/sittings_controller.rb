# Chooses where the scanner sitting's adds go (spec 040 Stories 1–4): one of the account's locations, or none. The answer
# is a Turbo Stream that redraws the panel, so the camera and the reading on screen stay (decision 3). The location is
# looked up through the account; a value that names none of its locations changes nothing (decision 7, AC-4.1).
class Scanner::SittingsController < ApplicationController
  include ScannerSitting

  GONE = "That location isn't one of yours any more. Choose again.".freeze

  def update
    value = params.expect(sitting: :location_id).fetch(:location_id).to_s # a missing key is a 400 (AC-3.3)
    location = Current.account.locations.find_by(id: value) if value.match?(/\A\d+\z/) # "12abc" is refused, not read as 12
    if value.present? && location.nil?
      return render(turbo_stream: sitting_stream(GONE, alert: true), status: :unprocessable_content)
    end

    sitting = Scanner::Sitting.place!(account: Current.account, location:)
    render turbo_stream: sitting_stream(placed_message(sitting))
  end

  private
    # Says where later adds go; nothing when clearing deleted the sitting, as the page is then as before any sitting.
    def placed_message(sitting)
      return unless sitting&.persisted? # a destroyed sitting still holds the place it had in memory

      sitting.location ? "This sitting's cards now go into #{sitting.location.name}." : "This sitting's cards now go in no location."
    end
end
