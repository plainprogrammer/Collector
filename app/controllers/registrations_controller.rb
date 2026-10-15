class RegistrationsController < ApplicationController
  allow_before_first_user
  allow_unauthenticated_access
  before_action :redirect_signed_in_users

  def new
    @first_user = !User.exists?
    @registration = Registration.new({}) if Registration.open?
  end

  def create
    @registration = Registration.new(registration_params)
    if (user = @registration.save)
      start_new_session_for(user)
      # Sign-up lands in the collection; a catalog page a visitor opened first isn't where a later sign-in goes (spec 023).
      session.delete(:return_to_after_authenticating)
      redirect_to collection_path, status: :see_other
    else
      @first_user = !User.exists? && !@registration.closed?
      render :new, status: :unprocessable_content
    end
  end

  private
    def registration_params = params.expect(user: Registration::PERMITTED)
end
