# On an instance with no users, every page goes to sign-up, which creates the first admin
# (spec 004 AC-3.1). The health check doesn't inherit ApplicationController, so it's exempt.
module FirstRun
  extend ActiveSupport::Concern

  included do
    before_action :require_first_user
  end

  class_methods do
    def allow_before_first_user(**options) = skip_before_action(:require_first_user, **options)
  end

  private
    def require_first_user
      redirect_to new_registration_path unless User.exists?
    end
end
