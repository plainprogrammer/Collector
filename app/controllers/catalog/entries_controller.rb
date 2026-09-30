class Catalog::EntriesController < ApplicationController
  def index
    @search = Catalog::Search.new(query: search_params[:q], set_code: search_params[:set], page: search_params[:page])
    @groups = @search.groups
    @owned = Lot.owned_quantities(Current.account, @groups.flat_map(&:entries).map(&:id))
    @sets = Catalog::Set.with_searchable_entries.newest_first.to_a
    @last_refresh = Catalog::RefreshRun.last_applied
  end

  def show
    @entry = Catalog::Entry.includes(:set, :identity).find_by!(external_key: params[:external_key])
    Catalog::Entry.preload_extensions([ @entry ])
    @overview = Catalog::CardOverview.new(account: Current.account, entry: @entry)
  end

  private
    def search_params = params.permit(:q, :set, :page)
end
