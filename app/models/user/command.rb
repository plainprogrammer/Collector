# Operator shell command: set a user's password, or create an admin (spec 004 AC-5.7, AC-3.6).
class User::Command
  def self.call(email:, password:)
    User.transaction do
      user = User.find_or_initialize_by(email_address: email.to_s.strip.downcase)
      created = user.new_record?
      if created
        user.assign_attributes(name: user.email_address.split("@").first.presence || user.email_address, admin: true)
        InstanceSetting.current.update!(sign_up_open: false)
      end
      user.password = password
      user.save!
      user.end_sessions! unless created
      [ user, created ]
    end
  end
end
