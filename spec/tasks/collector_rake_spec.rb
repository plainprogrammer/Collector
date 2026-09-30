require "rails_helper"
require "rake"
require "io/console"

RSpec::Matchers.define_negated_matcher :not_include, :include

RSpec.describe "collector:user", type: :task do
  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("collector:user")
    Rake::Task["collector:user"].reenable
    allow($stdin).to receive(:tty?).and_return(false)
  end

  def run_task(email)
    original_out, original_err = $stdout, $stderr
    $stdout = $stderr = StringIO.new
    Rake::Task["collector:user"].invoke(email)
    $stdout.string
  ensure
    $stdout, $stderr = original_out, original_err
  end

  it "uses COLLECTOR_PASSWORD and never prints it", :aggregate_failures do
    ENV["COLLECTOR_PASSWORD"] = "from the environment"
    output = run_task("owner@example.test")
    expect(User.find_by(email_address: "owner@example.test").authenticate("from the environment")).to be_truthy
    expect(output).to include("Created admin owner@example.test").and not_include("from the environment")
  ensure
    ENV.delete("COLLECTOR_PASSWORD")
  end

  it "prompts for the password in a terminal without echoing it", :aggregate_failures do
    allow($stdin).to receive_messages(tty?: true, noecho: "typed at the prompt\n")
    output = run_task("owner@example.test")
    expect(User.find_by(email_address: "owner@example.test").authenticate("typed at the prompt")).to be_truthy
    expect(output).to include("New password").and not_include("typed at the prompt")
  end

  it "generates and prints a password when none is given and stdin isn't a terminal", :aggregate_failures do
    password = run_task("owner@example.test")[/Password: (\S+)/, 1]
    expect(password.length).to be >= 16
    expect(User.find_by(email_address: "owner@example.test").authenticate(password)).to be_truthy
  end

  it "exits non-zero for a malformed email, creating nobody", :aggregate_failures do
    expect { run_task("nope") }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
    expect(User.count).to eq(0)
  end
end
