class Catalog::IdentitiesController < ApplicationController
  PER_PAGE = 12

  def show
    @identity = Catalog::Identity.find_by!(external_key: params[:external_key])
    raise ActiveRecord::RecordNotFound unless @identity.entries.searchable.exists?

    @set_code = printing_params[:set].presence
    scope = @identity.entries.searchable.in_set(@set_code)
    @pagination = Catalog::Pagination.for(total_count: scope.count, requested_page: printing_params[:page], per_page: PER_PAGE)
    @entries = Catalog::Entry.preload_extensions(
      scope.newest_first.includes(:set).offset(@pagination.offset).limit(PER_PAGE).to_a)
  end

  private
    def printing_params = params.permit(:set, :page)
end
