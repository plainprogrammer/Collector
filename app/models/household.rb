# A named group of accounts: today always one user's, from a later issue also a family's (spec 090, ADR 0030). It is the
# household's, not the collector's, so it is never scoped through `Current.account` and no request names one.
class Household < ApplicationRecord
  NAME_LIMIT = 100
  # The name of a household of one is the user's name followed by this: 12 characters, so the user's name is cut to 88.
  SUFFIX = "'s household".freeze

  has_many :memberships, dependent: nil # the foreign key has no action: a household that holds a member can't be deleted
  has_many :users, through: :memberships
  has_many :accounts, dependent: nil # likewise, so a delete can never reach an account and, through its cascades, a collection

  validates :name, presence: true, length: { maximum: NAME_LIMIT }

  before_destroy :refuse_while_held, prepend: true

  # The name a household of one gets (spec 090 decision 2): the user's first 88 characters and "'s household", at most 100.
  # `script/upgrade/households.rb` and the backfill migration build the same name in SQL with `substr`:
  # `spec/migrations/backfill_households_spec.rb` holds the backfill's SQL equal to this method, and
  # `spec/script/upgrade/households_spec.rb` builds its fixture names with it, against the check's SQL.
  #
  # @param user_name [String] the user's name
  # @return [String]
  def self.name_for(user_name) = "#{user_name.to_s.slice(0, NAME_LIMIT - SUFFIX.length)}#{SUFFIX}"

  private
    def refuse_while_held
      throw :abort if memberships.exists? || accounts.exists?
    end
end
