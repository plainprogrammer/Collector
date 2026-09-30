# Adds one copy of a printing with nothing else specified (spec 004 Story 7).
class Catalog::QuickAddsController < ApplicationController
  FULL_LOT = "You already have the most copies one lot can hold (9,999).".freeze

  def create
    @entry = Catalog::Entry.find_by!(external_key: params[:entry_external_key])
    Lot.add!(account: Current.account, entry: @entry)
    redirect_to safe_return_to(catalog_entry_path(@entry, **card_params)), status: :see_other,
      notice: "Added 1 × #{@entry.name} (#{helpers.set_number(@entry)}) to your collection."
  rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      # Scripting on (AC-7.3a): show the message and leave the page as it is.
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("status", partial: "shared/status_message", locals: { message: FULL_LOT, alert: true }),
          status: :unprocessable_content
      end
      format.html { render_full_lot }
    end
  end

  private
    # Replaced in Phase 8 by the card page rendered at 422.
    def render_full_lot = render(plain: FULL_LOT, status: :unprocessable_content)
end
