class CollectionsController < ApplicationController
  def root
    redirect_to collection_path
  end

  def show
    @grid = CollectionGrid.new(account: Current.account, query: params[:q], page: params[:page])
  end
end
