# "Other printings" for a scanned card (spec 009 Story 2): its printings in a Turbo Frame inside the reading, each with add
# buttons for the same reading, so the scanner and its camera stay on the page.
class Scanner::PrintingsController < ApplicationController
  def index
    @key = params.expect(:key)
    return head(:not_found) unless Scanner::Sitting::KEY_FORMAT.match?(@key)

    @identity = Catalog::Identity.where(collectible_type: MTG::Reading::COLLECTIBLE_TYPE).find_by!(external_key: params.expect(:card))
    @printings = Scanner::OtherPrintings.new(identity: @identity, set_code: params[:set], number: params[:number],
      artwork: params[:artwork].to_s[MTG::Art::Sent::ID]) # an invalid or unknown id is ignored (spec 011 AC-7.5)
    @finish_hint = params[:finish_hint].presence
  end
end
