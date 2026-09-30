class Admin::SignUpSettingsController < ApplicationController
  include AdminOnly

  def update
    open = params[:sign_up_open] == "1"
    InstanceSetting.current.update!(sign_up_open: open)
    redirect_to admin_users_path, notice: open ? "Sign-up is open." : "Sign-up is closed.", status: :see_other
  end
end
