class User < ApplicationRecord
  PASSWORD_MINIMUM = 12
  # One "@" with text on both sides and no whitespace (spec 004 AC-4.3).
  EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\z/
  COLLECTION_VIEWS = %w[grid table].freeze

  has_secure_password
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

  before_validation :build_account, on: :create, unless: :account

  validate :keeps_an_admin, on: :update, if: -> { admin_changed?(from: true, to: false) }

  scope :admins, -> { where(admin: true) }

  def initial = name.to_s.first.to_s.upcase

  def end_sessions! = sessions.delete_all

  private
    def keeps_an_admin
      errors.add(:admin, "can't be removed: Collector needs at least one admin.") if User.admins.where.not(id:).none?
    end
end
