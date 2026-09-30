class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  before_action :redirect_signed_in_users, only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create,
    store: Rails.application.config.x.sign_in_rate_limit_store || Rails.cache,
    by: -> { "#{request.remote_ip}|#{params[:email_address].to_s.strip.downcase}" },
    with: -> { render_new("Too many attempts. Try again in a few minutes.", :too_many_requests) }

  def new
  end

  def create
    if (user = User.authenticate_by(email_address: params[:email_address].to_s, password: params[:password].to_s))
      start_new_session_for(user)
      redirect_to after_authentication_url, status: :see_other
    else
      render_new("Email or password is incorrect.", :unprocessable_content)
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private
    def render_new(message, status)
      flash.now[:alert] = message
      render :new, status:
    end
end
