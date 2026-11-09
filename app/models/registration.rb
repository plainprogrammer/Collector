# Sign-up: creates the first admin on an empty instance, or a regular user while sign-up is open
# (spec 004 AC-3.2, AC-3.4, AC-4.1, AC-4.2). The check and the insert share one IMMEDIATE write
# transaction, so two submissions can't both become the first admin.
class Registration
  PERMITTED = %i[name email_address password password_confirmation].freeze

  attr_reader :user

  def self.open? = !User.exists? || InstanceSetting.current.sign_up_open?

  def initialize(params)
    attributes = params.to_h.symbolize_keys.slice(*PERMITTED)
    # has_secure_password compares a confirmation only when one is sent, and AC-4.1 asks for a matching one: a sign-up
    # that omits the field is checked as the empty confirmation it is, so it gets a mismatch's error (AC-4.3; #230).
    attributes[:password_confirmation] = attributes[:password_confirmation].to_s
    @user = User.new(attributes)
    @closed = false
  end

  def closed? = @closed

  def save
    User.transaction do
      first = !User.exists?
      next @closed = true unless first || InstanceSetting.current.sign_up_open?

      user.admin = first
      next unless user.save

      InstanceSetting.current.update!(sign_up_open: false) if first
      user
    end.then { |result| result.is_a?(User) ? result : false }
  end
end
