require "rails_helper"
require "rake"
require Rails.root.join("lib/collector/start_check").to_s

# The container's start check at process level (spec 086): the task has no :environment prerequisite and nothing on the
# application's boot path reaches it (decisions 1, 3 and 5; AC-2.6).
RSpec.describe "the start check", :backup, type: :task do
  # Every file a boot of the application reads: initializers, the application and environment configuration, and app/.
  def boot_files
    Rails.root.glob("{config/initializers/**/*.rb,config/application.rb,config/environments/*.rb,app/**/*.rb}")
  end

  # The code lines of a file, without comments and without config/application.rb's autoload_lib(ignore:) line, which
  # names the file so that Zeitwerk leaves it alone and is no run of it.
  def code_lines(file)
    file.each_line.reject { it.include?("autoload_lib(ignore:") }.map { it.sub(/(\A|\s)#.*/, "") }
  end

  it "gives start:check no dependency on :environment, so it initializes nothing (AC-2.6)" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("start:check")

    expect(Rake::Task["start:check"].all_prerequisite_tasks.map(&:name)).not_to include("environment")
  end

  it "is not named by any initializer, configuration file or app file, so no boot runs it (AC-2.6)" do
    named = boot_files.select { |file| code_lines(file).any? { it.match?(/StartCheck|start_check/) } }

    expect(named).to be_empty, "these files name the start check: #{named.join(", ")}"
  end

  # The entrypoint itself, run for real on a scratch volume (spec 086 decision 6). The command "echo ./bin/rails server"
  # matches the entrypoint's server-start condition and its exec runs echo, so "the server was not run" is the absence of
  # "./bin/rails server" in standard output. The check and db:prepare run for real against the scratch files.
  describe "bin/docker-entrypoint" do
    let(:volume) { scratch("volume") }
    let(:prices) { volume.join("production_prices.sqlite3") }
    let(:primary) { volume.join("production.sqlite3") }
    let(:refusal_lines) { Collector::StartCheck.refusal(databases: databases_for(volume)) }
    # The child of a killed restore has no Rails, so every path and version list is an argument (as restore_spec's).
    let(:killed_child) do
      <<~'RUBY'
        files = { "primary" => "production.sqlite3", "cache" => "production_cache.sqlite3", "queue" => "production_queue.sqlite3", "cable" => "production_cable.sqlite3", "prices" => "production_prices.sqlite3" }
        databases = Collector::Backup::Databases.new(files.transform_values { |name| Pathname(ARGV[1]).join(name) })
        Collector::Backup::Restore.new(file: ARGV[0], databases: databases, release_versions: JSON.parse(ARGV[2]), release_prices_versions: JSON.parse(ARGV[3]), checkpoint: STOP_HERE).call
      RUBY
    end

    # The entrypoint on the scratch volume, with the environment app_command gives a child and a SCHEMA path of its own
    # for each run (a second run must not load the first one's dump).
    def entrypoint(*command, environment: {})
      env = { "RAILS_ENV" => "test", "DATABASE_URL" => "sqlite3:#{primary}", "PRICES_DATABASE_URL" => "sqlite3:#{prices}",
        "SCHEMA" => scratch_path("schema-#{SecureRandom.hex(4)}.dump").to_s }.merge(environment)
      Open3.capture3(env, Rails.root.join("bin/docker-entrypoint").to_s, *(command.presence || %w[echo ./bin/rails server]), chdir: Rails.root.to_s)
    end

    def volume_files = volume.children.map { it.basename.to_s }.sort

    # The restore's second placing never happened: the prices file is the restored one, the primary is missing.
    def kill_a_restore
      seed = seed_instance
      seed_prices(entry_ids: seed.entries.map(&:id))
      create_backup.tap { run_killed_at(:prices_placed, killed_child, it, volume, release_versions.to_json, Collector::Backup.release_schema_versions(Rails.root, "db/prices_migrate").to_json) }
    end

    it "refuses a volume with a prices file and no primary before db:prepare: status 1, the message on standard error, nothing changed", :aggregate_failures do
      prices.write("stale")
      before = [ checksums(volume), volume_files ]
      out, err, status = entrypoint

      expect(status.exitstatus).to eq(1)
      expect(out).to be_empty
      expect(err.lines(chomp: true)).to eq(refusal_lines)
      expect([ checksums(volume), volume_files ]).to eq(before)
    end

    it "refuses in production without a secret, with the same message and no word about secret_key_base", :aggregate_failures do
      prices.write("stale")
      _out, err, status = entrypoint(environment: { "RAILS_ENV" => "production", "SECRET_KEY_BASE" => nil, "SECRET_KEY_BASE_DUMMY" => nil, "RAILS_MASTER_KEY" => "0" * 32 })

      expect(status.exitstatus).to eq(1)
      expect(err.lines(chomp: true)).to eq(refusal_lines)
      expect(err).not_to include("secret_key_base")
    end

    it "doesn't run for a one-off command on the refused volume", :aggregate_failures do
      prices.write("stale")
      before = [ checksums(volume), volume_files ]
      out, _err, status = entrypoint("echo", "hello")

      expect([ status.exitstatus, out ]).to eq([ 0, "hello\n" ])
      expect([ checksums(volume), volume_files ]).to eq(before)
    end

    context "when the volume is passed" do
      it "starts a new instance on an empty volume and creates both databases (AC-2.1)", :aggregate_failures do
        out, err, status = entrypoint

        expect(status).to be_success, err
        expect(out.lines.last).to eq("./bin/rails server\n")
        expect(volume_files).to include("production.sqlite3", "production_prices.sqlite3")
      end

      it "starts on a primary and a prices file (AC-2.2)", :aggregate_failures do
        entrypoint
        out, err, status = entrypoint

        expect(status).to be_success, err
        expect(out.lines.last).to eq("./bin/rails server\n")
      end

      it "starts after the prices file and its sidecars are removed, as a new instance (AC-2.7)", :aggregate_failures do
        %w[ -wal -shm -journal ].unshift("").each { volume.join("production_prices.sqlite3#{it}").write("stale") }
        expect(entrypoint[2].exitstatus).to eq(1)
        volume.children.each(&:delete)
        out, err, status = entrypoint

        expect(status).to be_success, err
        expect(out.lines.last).to eq("./bin/rails server\n")
        expect(volume_files).to include("production.sqlite3", "production_prices.sqlite3")
      end
    end

    context "with a committed instance", :committed do
      it "starts on a primary alone and creates the prices database (AC-2.3)", :aggregate_failures do
        seed_instance
        FileUtils.cp(copy_of_instance, primary)
        out, err, status = entrypoint

        expect(status).to be_success, err
        expect(out.lines.last).to eq("./bin/rails server\n")
        expect(prices).to exist
      end

      it "after a killed restore, refuses the volume and leaves the restored prices file, then starts on the restore that follows its removal (AC-1.5, AC-2.7)", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- one scenario: kill, refuse, remove, restore, start
        backup = kill_a_restore
        before = [ checksums(volume), volume_files ]
        out, err, status = entrypoint

        expect([ status.exitstatus, out ]).to eq([ 1, "" ])
        expect(err.lines(chomp: true)).to eq(refusal_lines)
        expect([ checksums(volume), volume_files ]).to eq(before)
        expect(sqlite(prices, readonly: true) { it.get_first_value("SELECT count(*) FROM current_prices") }).to eq(3)

        prices.delete
        restore_backup(backup, volume:)
        out, err, status = entrypoint
        expect(status).to be_success, err
        expect(out.lines.last).to eq("./bin/rails server\n")
        expect(sqlite(primary, readonly: true) { it.get_first_value("SELECT count(*) FROM lots") }).to eq(3)
      end
    end
  end
end
