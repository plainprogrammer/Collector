# The no-script confirmation page for removing a lot (spec 004 AC-10.5).
class Lots::RemovalsController < ApplicationController
  def new
    @lot = Current.account.lots.includes(entry: :set).find(params[:lot_id])
  end
end
