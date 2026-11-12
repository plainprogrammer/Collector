# Spec 071: "Add to deck" from the card page. The printing is found by its key and must be one a collector can add to a deck
# (`Catalog::Entry#deck_addable?`: live, a card, its type registered), else 404; the zone and the lots go through
# `Current.account` (`Deck::Addition`). Signed-out visitors are sent to sign in by the application controller: this page is not
# part of the open catalog.
# @see file:collection-and-lots.md
class DeckAdditionsController < ApplicationController
  before_action :set_entry

  # A zone removed while the form was open: the foreign key (the proxy path) or the lookup (the take) refused it.
  rescue_from(ActiveRecord::InvalidForeignKey) { raise ActiveRecord::RecordNotFound }

  # The form, with nothing chosen but what the page itself decides (`Deck::Addition#chosen`).
  def new
    @addition = build
  end

  # Writes the move or the proxy; 303 to the card page with a notice, or the form again with a 422 and the sentences.
  def create
    @addition = build(addition_params)
    return render(:new, status: :unprocessable_content) unless @addition.save

    redirect_to catalog_entry_path(@entry, **card_params), status: :see_other, notice: notice_for(@addition)
  end

  private
    def set_entry
      @entry = Catalog::Entry.includes(:set, :identity).find_by!(external_key: params[:entry_external_key])
      raise ActiveRecord::RecordNotFound, "not a printing to add to a deck" unless @entry.deck_addable?

      Catalog::Entry.preload_extensions([ @entry ])
    end

    def build(fields = {}) = Deck::Addition.new(account: Current.account, entry: @entry, **fields)

    # Flat fields, permitted by name: `params.expect` answers 400 when the browser omits an unchosen radio, and AC-5.1 wants a
    # 422 with a sentence; permit only `:zone_id, :quantity, :use`, never an account, user, location or kind (AC-5.3).
    def addition_params = params.permit(:zone_id, :quantity, :use).to_h.symbolize_keys

    # The sentence after a success: a proxy as spec 068 words its notice, a move in copies (decision 10).
    def notice_for(addition)
      if addition.proxy
        added = helpers.pluralize(helpers.number_with_delimiter(addition.count), "proxy", "proxies")
        "Added #{added} of #{helpers.proxy_name(addition.proxy)} to #{addition.zone.label}."
      else
        "Moved #{helpers.pluralize(helpers.number_with_delimiter(addition.count), "copy", "copies")} of #{@entry.name} to #{addition.zone.label}."
      end
    end
end
