# Starts one of a catalog type's operations (spec 015 FR-3): queues its job, never runs it in the request. The type and
# the operation are looked up among what is registered, so an unknown one is a 404 and nothing from the request is ever
# called by name (FR-7).
class Admin::Catalogs::OperationStartsController < ApplicationController
  include AdminOnly

  def create
    operation = Catalog::Health.find(params[:collectible_type]).operation(params[:operation])
    raise ActiveRecord::RecordNotFound unless operation

    if operation.start
      redirect_to admin_catalog_path, notice: operation.queued_notice, status: :see_other
    elsif operation.unavailable_reason
      redirect_to admin_catalog_path, alert: operation.unavailable_reason, status: :see_other
    else
      redirect_to admin_catalog_path, notice: operation.in_flight_notice, status: :see_other
    end
  end
end
