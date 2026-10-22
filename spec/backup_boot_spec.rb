require "rails_helper"
require "rake"

RSpec.describe "the tasks need no secret (spec 030 decision 4, research.md 1)", :backup, type: :task do
  # No SECRET_KEY_BASE, no dummy. The tasks read no credentials, so a wrong master key is harmless to them and keeps a
  # developer's real config/master.key from supplying a secret_key_base. A boot is different: see boot below.
  def production(*command, environment: {})
    env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE" => nil, "SECRET_KEY_BASE_DUMMY" => nil, "RAILS_MASTER_KEY" => "0" * 32,
      "DATABASE_URL" => "sqlite3:#{scratch_path("boot.sqlite3")}" }.merge(environment)
    Open3.capture3(env, Rails.root.join("bin/rails").to_s, *command, chdir: Rails.root.to_s)
  end

  # A production boot with no master key at all: credentials come back empty (EncryptedFile#read raises
  # MissingContentError, which EncryptedConfiguration rescues), as in the image, which has no key file.
  def boot(*command, environment: {})
    skip "config/master.key exists on this machine; the boot examples need an environment without a key (CI has none)" if Rails.root.join("config/master.key").exist?

    production(*command, environment: { "RAILS_MASTER_KEY" => nil }.merge(environment))
  end

  def storage_files = Dir[Rails.root.join("storage/production*").to_s].sort

  it "gives neither task a dependency on :environment, so neither initializes the application (the structural guarantee)", :aggregate_failures do
    Rails.application.load_tasks unless Rake::Task.task_defined?("backup:create")

    %w[backup:create backup:restore].each do |name|
      expect(Rake::Task[name].all_prerequisite_tasks.map(&:name)).not_to include("environment"), name
    end
  end

  it "runs backup:restore in production and answers its own refusal, without a secret", :aggregate_failures do
    before = storage_files
    out, err, status = production("backup:restore")

    expect(status.exitstatus).to eq(1)
    expect(out).to be_empty
    expect(err.lines(chomp: true)).to eq([ "No file was given.", %(Run: bin/rails "backup:restore[/path/to/collector-backup.tar.gz]".) ])
    expect(storage_files).to eq(before)
  end

  it "runs backup:create in production the same way", :aggregate_failures do
    out, err, status = production("backup:create")

    expect([ status.exitstatus, out ]).to eq([ 1, "" ])
    expect(err.lines.first).to eq("No directory was given.\n")
  end

  it "would fail if they booted the application, which reads secret_key_base eagerly (the control)", :aggregate_failures do
    before = storage_files
    _out, err, status = boot("runner", "puts :booted")

    expect(status.exitstatus).not_to eq(0)
    expect(err).to include('secret_key_base') # not a credentials error: that would prove nothing about the secret
    expect(storage_files).to eq(before)
  end

  it "boots with the dummy, which is enough, as the documented one-off passes it", :aggregate_failures do
    before = storage_files
    out, err, status = boot("runner", "puts :booted", environment: { "SECRET_KEY_BASE_DUMMY" => "1" })

    expect(status).to be_success, err
    expect(out).to include("booted")
    expect(storage_files).to eq(before)
  end
end
