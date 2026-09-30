# The no-script confirmation page for deleting a user (spec 004 FR-5, AC-5.4).
class Admin::Users::DeletionsController < ApplicationController
  include AdminOnly

  def new
    @user = User.find(params[:user_id])
  end
end
