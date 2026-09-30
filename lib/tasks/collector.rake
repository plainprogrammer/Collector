namespace :collector do
  desc "Set a user's password, or create an admin with that email (password from COLLECTOR_PASSWORD, a prompt, or generated)"
  task :user, [ :email ] => :environment do |_task, args|
    password = ENV["COLLECTOR_PASSWORD"].presence
    generated = false
    if password.nil? && $stdin.tty?
      require "io/console"
      print "New password (at least #{User::PASSWORD_MINIMUM} characters): "
      password = $stdin.noecho(&:gets).to_s.chomp
      puts
    end
    if password.blank?
      password = SecureRandom.base58(24)
      generated = true
    end

    user, created = User::Command.call(email: args[:email], password:)
    puts created ? "Created admin #{user.email_address}." : "Set a new password for #{user.email_address} and signed them out everywhere."
    puts "Password: #{password}" if generated
  rescue ActiveRecord::RecordInvalid => error
    warn "Could not save #{args[:email].inspect}: #{error.record.errors.full_messages.to_sentence}"
    exit 1
  end
end
