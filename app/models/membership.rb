# One user in one household, as a manager or a member (spec 090, ADR 0030). A household always has a manager: the model
# refuses to demote the last one and to remove a membership on its own; a membership goes with its user (`User` deletes it
# without these callbacks, and the database cascades). The role check and the unique user are the database's too.
class Membership < ApplicationRecord
  belongs_to :household
  belongs_to :user

  enum :role, { manager: "manager", member: "member" }, validate: true

  validates :user_id, uniqueness: true, allow_nil: true
  validate :keeps_a_manager, on: :update, if: -> { role_changed?(from: "manager") }

  before_destroy { throw :abort }

  # Whether this is its household's only manager.
  #
  # @return [Boolean]
  def last_manager? = manager? && !household.memberships.manager.where.not(id:).exists?

  private
    def keeps_a_manager
      errors.add(:role, "can't change: a household needs a manager.") unless household.memberships.manager.where.not(id:).exists?
    end
end
