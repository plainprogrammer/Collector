class Catalog::EntriesController < ApplicationController
  def index
    @search = Catalog::Search.new(query: search_params[:q], set_code: search_params[:set], page: search_params[:page])
    @groups = @search.groups
    @sets = Catalog::Set.with_searchable_entries.newest_first.to_a
    @last_refresh = Catalog::RefreshRun.last_applied
  end

  private
    def search_params = params.permit(:q, :set, :page)
end
