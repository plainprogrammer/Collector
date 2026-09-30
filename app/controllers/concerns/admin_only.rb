# Admin pages and actions are invisible to everyone else (spec 004 AC-5.6).
module AdminOnly
  extend ActiveSupport::Concern

  included do
    before_action { raise ActiveRecord::RecordNotFound unless Current.user&.admin? }
  end
end
