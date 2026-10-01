# The collection page (spec 004 Story 11, spec 006 Story 2): the grid, or the table with ?view=table.
class CollectionsController < ApplicationController
  include CollectionListing

  def root
    redirect_to collection_path
  end

  def show
    prepare_collection(query: params[:q], sort: CollectionTable::Sort.parse(params[:sort], params[:dir]), page: params[:page],
      view: params[:view] == "table" ? "table" : "grid", bulk: false)
  end
end
