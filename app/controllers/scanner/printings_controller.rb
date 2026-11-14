# The selection frame for one card (spec 088 decisions 3, 4, 15; reworks spec 009 Story 2's Other printings): its printings with
# one first, 20 at a time, for "All printings" from a possible-cards row and "Show 20 more". The same partial the reading's answer
# renders, so the camera and the scanner stay on the page. Params: card (the identity's external key), key (the reading key),
# set, number, finish_hint, artwork (as the reading's candidates carry them), match (the printing that goes first), band (its
# band state, a closed list), limit and current (the printing to centre).
class Scanner::PrintingsController < ApplicationController
  def index
    key = params.expect(:key)
    return head(:not_found) unless Scanner::Sitting::KEY_FORMAT.match?(key)

    identity = Catalog::Identity.where(collectible_type: MTG::Reading::COLLECTIBLE_TYPE).find_by!(external_key: params.expect(:card))
    artwork = params[:artwork].to_s[MTG::Art::Sent::ID] # an invalid or unknown id is ignored (spec 011 AC-7.5)
    match = identity.entries.includes(:set).find_by(external_key: params[:match].to_s) ||
      Scanner::OtherPrintings.new(identity:, set_code: params[:set], number: params[:number], artwork:).entries.first
    return head(:not_found) unless match

    Catalog::Entry.preload_extensions([ match ])
    @selection = Scanner::Selection.for_card(identity:, match:, state: params[:band], key:, set: params[:set].to_s.presence, number: params[:number].to_s.presence,
      finish_hint: params[:finish_hint].to_s.presence, artwork:, limit: params[:limit], current: params[:current].to_s.presence)
  end
end
