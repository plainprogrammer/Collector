# Runs the job of one of a catalog type's operations that waits to retry, at once (spec 055). The type and the operation
# are looked up among what is registered, so an unknown one is a 404 and nothing from the request is ever called by name;
# the job comes from the operation's own latest failed run, never from the request (decision 4). Nothing is queued or run
# in the request: the waiting job's scheduled entry becomes ready, and a worker runs it.
class Admin::Catalogs::OperationRetriesController < ApplicationController
  include AdminOnly

  def create
    operation = Catalog::Health.find(params[:collectible_type]).operation(params[:operation])
    raise ActiveRecord::RecordNotFound unless operation

    notice = operation.retry_now ? "Retrying now." : "Nothing is waiting to retry."
    redirect_to admin_catalog_path, notice:, status: :see_other
  end
end
