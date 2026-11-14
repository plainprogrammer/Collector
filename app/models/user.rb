class User < ApplicationRecord
  PASSWORD_MINIMUM = 12
  # One "@" with text on both sides and no whitespace (spec 004 AC-4.3).
  EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\z/
  COLLECTION_VIEWS = %w[grid table].freeze

  has_secure_password
  # Deleted without callbacks (Membership refuses a direct destroy; the database would cascade it anyway), before the user's row.
  has_one :membership, dependent: :delete, inverse_of: :user, autosave: true
  belongs_to :account, dependent: :destroy
  has_many :sessions, dependent: :delete_all

  normalizes :email_address, with: ->(email) { email.strip.downcase }
  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: 100 }
  validates :email_address, presence: true, uniqueness: { message: "is already used" },
    format: { with: EMAIL_FORMAT, message: "must look like name@example.com", allow_blank: true }
  validates :password, length: { minimum: PASSWORD_MINIMUM, message: "must be at least #{PASSWORD_MINIMUM} characters" },
    allow_nil: true
  validates :collection_view, inclusion: { in: COLLECTION_VIEWS }

  validates :membership, presence: true, on: :create
  # Only when both are loaded (a new user, or a user a caller loaded both for): an update of a signed-in user, whose account the
  # session loads, must not read a household (spec 090 Story 4, AC-4.5). `association_cached?` first: `association(:membership)` would
  # otherwise create the association instance, and the next validation's autosave check would then read it.
  validate :membership_is_in_the_accounts_household, if: -> { association_cached?(:membership) && association(:membership).loaded? && association(:account).loaded? }

  before_validation :build_account_and_household, on: :create, unless: :account
  before_destroy :keep_a_manager_for_the_others, prepend: true
  after_destroy :remove_an_empty_household # after the account's, which `belongs_to … dependent: :destroy` registers above

  validate :keeps_an_admin, on: :update, if: -> { admin_changed?(from: true, to: false) }

  scope :admins, -> { where(admin: true) }

  def initial = name.to_s.first.to_s.upcase

  def end_sessions! = sessions.delete_all

  private
    # A user is made with its account and its household of one, as the manager (spec 090 decision 8): one write, so a failed
    # save leaves none of the three.
    def build_account_and_household
      household = Household.new(name: Household.name_for(name))
      build_account(household:)
      build_membership(household:, role: :manager)
    end

    def membership_is_in_the_accounts_household
      return unless membership && account

      errors.add(:membership, "must be in the household of the account") unless membership.household == account.household
    end

    # A household can't lose its last manager by deleting the user while others are in it (spec 090 decision 7); a page that
    # makes such a household (#382, #383) gives it a message. Remembers the household for the delete's last step.
    def keep_a_manager_for_the_others
      @leaving_household = membership&.household
      return unless membership&.last_manager? && membership.household.memberships.where.not(id: membership.id).exists?

      errors.add(:base, "is the last manager of a household that has other members.")
      throw :abort
    end

    # The household of a user whose delete left no member and no account goes with them; `Household` refuses while it holds either.
    def remove_an_empty_household = @leaving_household&.destroy

    def keeps_an_admin
      errors.add(:admin, "can't be removed: Collector needs at least one admin.") if User.admins.where.not(id:).none?
    end
end
