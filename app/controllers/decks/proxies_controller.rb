# Spec 068 Stories 1 and 3: a deck zone's proxies. The deck is found by its location id through the account and the zone by its
# key within it; a proxy by its id among the deck's. Nothing in a request names an account, a zone id or a kind (AC-1.11).
# @see file:collection-and-lots.md
class Decks::ProxiesController < ApplicationController
  include FindsDeck

  before_action :set_deck
  before_action :set_zone, :require_vocabulary, only: %i[new create]
  before_action :set_proxy, only: %i[edit update destroy]

  # The chooser (a search of the deck's collectible type), or with `entry` the form for that printing.
  def new
    return render_form(Deck::Proxy::Addition.new(account: Current.account, zone: @zone, entry: find_entry(params[:entry]))) if params[:entry].present?

    @search = Catalog::Search.new(query: search_params[:q], set_code: search_params[:set], page: search_params[:page], collectible_type: @deck.collectible_type)
    @groups = @search.groups
    @sets = Catalog::Set.with_searchable_entries.newest_first.to_a
    render :choose
  end

  # Adds the quantity to the zone's proxy of that printing and finish, or makes one (decision 4).
  def create
    entry = find_entry(proxy_params[:entry])
    @addition = Deck::Proxy::Addition.new(account: Current.account, zone: @zone, entry:, finish: proxy_params[:finish], quantity: proxy_params[:quantity])
    if @addition.save
      added = helpers.pluralize(Deck::Proxy.parse_quantity(@addition.quantity), "proxy", "proxies")
      redirect_to deck_path(@deck), status: :see_other,
        notice: "Added #{added} of #{helpers.proxy_name(@addition.proxy)} to #{helpers.proxy_zone_label(@deck, @zone)}."
    else
      render_form(@addition, status: :unprocessable_content)
    end
  end

  # The Change proxy count page (T10).
  def edit
  end

  # Sets the proxy's quantity (T10).
  def update
    count = Deck::Proxy.parse_quantity(proxy_params[:quantity])
    return refuse_quantity(proxy_params[:quantity]) unless count

    @proxy.change_quantity!(count)
    redirect_to deck_path(@deck), status: :see_other,
      notice: "Changed the proxies of #{helpers.proxy_name(@proxy)} in #{helpers.proxy_zone_label(@deck, @proxy.zone)} to #{helpers.number_with_delimiter(count)}."
  end

  # Removes the proxy (T10); the confirmation page is `Decks::Proxies::RemovalsController#new`.
  def destroy
    @proxy.destroy!
    redirect_to deck_path(@deck), status: :see_other,
      notice: "Removed the proxies of #{helpers.proxy_name(@proxy)} from #{helpers.proxy_zone_label(@deck, @proxy.zone)}."
  end

  private
    def set_zone = @zone = @deck.zones.find_by!(zone: params[:zone].to_s)

    # The vocabulary and the source name the finishes and the search; a deck whose collectible the instance lost has neither,
    # so the add pages are 404 for it (decision 19) while its proxies still show and export.
    def require_vocabulary
      type = @deck.collectible_type
      raise ActiveRecord::RecordNotFound, "no vocabulary" unless Catalog.collecting.key?(type) && Catalog.sources.key?(type)
    end

    # A searchable printing of the deck's own collectible type: a retired one, a token and another type's are 404 (AC-1.10).
    def find_entry(key)
      entry = Catalog::Entry.searchable.includes(:set).find_by!(collectible_type: @deck.collectible_type, external_key: key.to_s)
      Catalog::Entry.preload_extensions([ entry ])
      entry
    end

    def render_form(addition, status: :ok)
      @addition = addition
      vocabulary = Catalog.collecting_for(addition.entry.collectible_type)
      @finishes = vocabulary.finishes_for(addition.entry).map { [ vocabulary.finish_label(it), it ] }
      render :new, status:
    end

    def refuse_quantity(typed)
      @typed = typed.to_s
      @quantity_error = @typed.strip == "0" ? "#{Deck::Proxy::Addition::QUANTITY_SENTENCE} To remove it, use Remove proxy." : Deck::Proxy::Addition::QUANTITY_SENTENCE
      render :edit, status: :unprocessable_content
    end

    def search_params = params.permit(:q, :set, :page)

    def proxy_params = params.expect(proxy: %i[entry finish quantity])
end
