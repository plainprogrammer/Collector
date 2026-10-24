# The upgrade proof (spec 031): boots the previous release's image, seeds it through its own code, starts the image built
# from the code under test on the same volume, and fails unless the database upgraded unattended, lost nothing and the app
# serves the collection as it was. Orchestration only: the commands are Upgrade::Engine's, the reading of the databases is
# Upgrade::Snapshot and Upgrade::Compare, the rules Upgrade::ExpectedChanges and Upgrade::SeedExceptions.
require "fileutils"
require "json"
require "json_schemer"
require "optparse"
require "timeout"
require "tmpdir"
require_relative "release"
require_relative "snapshot"
require_relative "compare"
require_relative "rules"
require_relative "engine"
require_relative "web"

module Upgrade
  class Harness
    Failure = Class.new(StandardError)
    Options = Struct.new(:previous_version, :previous_ref, :timeout, :boot_attempts, :platform, :repository, keyword_init: true)
    Instance = Struct.new(:name, :port, :volume)

    REPOSITORY = "ghcr.io/plainprogrammer/collector".freeze
    PULL_ATTEMPTS = 3
    PERMANENT_PULL_FAILURE = /manifest unknown|not found|no matching manifest|unauthorized|denied|requested access|invalid reference/i
    SEED_LINE = "UPGRADE-SEED-COMPLETE ".freeze
    SECRET = "secret-of-the-previous-release-instance-0001".freeze
    RESTORE_SECRET = "a-different-secret-of-the-restored-instance-0002".freeze
    RECURRING = <<~'RUBY'.freeze
      require "yaml"
      expected = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).fetch("production").keys.sort
      puts SolidQueue::RecurringTask.pluck(:key).sort == expected
    RUBY
    ENQUEUE = <<~'RUBY'.freeze
      job = Catalog::RefreshJob.set(wait: 1.year).perform_later("mtg", "upgrade-enqueued")
      puts SolidQueue::Job.where(active_job_id: job.job_id).exists?
    RUBY

    def self.parse(argv, env: ENV)
      options = Options.new(timeout: 600, boot_attempts: Integer(env.fetch("SMOKE_BOOT_ATTEMPTS", 60)),
        repository: env.fetch("UPGRADE_IMAGE_REPOSITORY", REPOSITORY))
      rest = OptionParser.new do |parser|
        parser.on("--previous-version VERSION") { options.previous_version = it }
        parser.on("--previous-ref REF") { options.previous_ref = it }
        parser.on("--timeout SECONDS", Integer) { options.timeout = it }
        parser.on("--platform PLATFORM") { options.platform = it }
      end.parse(argv)
      raise ArgumentError, "usage: bin/upgrade-smoke <previous|auto> <current> [--previous-version X.Y.Z | --previous-ref REF] [--timeout SECONDS] [--platform P]" unless rest.size == 2

      [ rest.first, rest.last, options ]
    end

    # Rails prints "== 20261021100001 CreateLocations: migrating" before it runs a migration (AC-3.3).
    def self.failed_migration(log) = log.scan(/^==\s+(\d{14})\s+(\w+):\s+migrating/).last&.join(" ")

    def initialize(previous:, current:, release:, engine:, options:, web: Web.method(:new), out: $stdout, root: Dir.pwd, sleeper: Kernel.method(:sleep))
      @previous_arg = previous
      @current = current
      @release = release
      @engine = engine
      @options = options
      @web = web
      @out = out
      @root = root
      @sleeper = sleeper
      @tag = Process.pid
      @containers = []
      @volumes = []
      @step = "start"
    end

    def call
      @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      Timeout.timeout(@options.timeout) { prove }
      0
    rescue Failure, Engine::Failure, Snapshot::Missing, Release::Error => error
      report_failure(error.message)
    rescue Timeout::Error
      report_failure("exceeded #{@options.timeout} s (elapsed #{elapsed} s)")
    rescue StandardError => error # an export or seed line that isn't JSON, a copy SQLite can't read: still AC-7.5's report, never a bare backtrace
      report_failure("#{error.class}: #{error.message}")
    ensure
      clean_up
    end

    private
      def prove
        return unless resolve

        find_seed_and_rules if @plan[:version] || !@plan[:release]
        fetch_previous
        find_seed_and_rules unless @seed
        @scratch = Dir.mktmpdir("upgrade-smoke")
        old = previous_database
        tables = upgrade(old)
        behaviour_after_upgrade
        backup_leg(old)
        next_release
        @out.puts "OK: #{@plan[:tag]} (#{@digest}) upgraded to #{@release.head[0, 12]}; #{tables} tables compared, behaviour verified, #{elapsed} s"
      end

      # -- steps ---------------------------------------------------------------------------------------------------

      def step(name)
        @step = name
        @out.puts "== #{name}"
      end

      def resolve
        step("resolve")
        @plan =
          if @previous_arg == "auto" then auto_plan
          elsif @options.previous_ref then ref_plan
          else { release: true, tag: nil, version: nil, ref: nil, image: @previous_arg, pull: false }
          end
        @plan&.tap { @out.puts "previous release: #{it[:tag] || "to be read from #{it[:image]}"}" }
      end

      def auto_plan
        version = @release.previous
        if version.nil?
          @out.puts "no previous release; nothing to upgrade from"
          return
        end
        { release: true, tag: version.tag, version: version.number, ref: version.tag, image: "#{@options.repository}:#{version.number}", pull: true }
      end

      def ref_plan
        ref = @options.previous_ref
        @out.puts "this run is not a release proof: #{@previous_arg} is the build of #{ref}; the seed is next.rb and its exceptions are the `next` ones"
        { release: false, tag: ref, version: nil, ref:, image: @previous_arg, pull: false }
      end

      def find_seed_and_rules
        step("seed and rules")
        name = @plan[:release] ? "#{@plan[:version]}.rb" : "next.rb"
        @seed = File.join(@root, "script/upgrade/seeds", name)
        unless File.file?(@seed)
          raise Failure, "no seed for #{@plan[:tag]}: expected script/upgrade/seeds/#{name}. Cutting a release creates it by renaming seeds/next.rb (docs/releasing.md, \"Cutting a release\")"
        end

        exceptions = SeedExceptions.load(File.join(@root, "script/upgrade/seed_exceptions.yml"), @plan[:release] ? @plan[:version] : "next")
        changes = ExpectedChanges.load(File.join(@root, "script/upgrade/expected_changes.yml"),
          previous_versions: @release.migration_versions(@plan[:ref]), current_versions: working_versions)
        problems = exceptions.errors + changes.errors
        raise Failure, "script/upgrade yml files: #{problems.join("; ")}" if problems.any?

        @exceptions = exceptions.entries
        @changes = changes
        changes.retired.each { @out.puts "retired: #{[ it.table, it.column ].compact.join(".")} #{it.kind} (migration #{it.migration} is in #{@plan[:tag]})" }
      end

      def fetch_previous
        step("pull")
        image = @plan[:image]
        pull(image) if @plan[:pull] || @engine.image_info(image).nil?
        info = @engine.image_info(image) || raise(Failure, "#{image} is not in the engine after pulling")
        labels = info.dig("Config", "Labels") || {}
        @digest = Array(info["RepoDigests"]).first || info["Id"]
        settle_version(labels) if @plan[:release] && @plan[:version].nil?
        @out.puts "previous: #{@plan[:tag]}  image #{image}  digest #{@digest}  version #{labels["org.opencontainers.image.version"] || "unknown"}  revision #{labels["org.opencontainers.image.revision"] || "unknown"}"
      end

      def pull(image)
        last = nil
        PULL_ATTEMPTS.times do |attempt|
          last = @engine.pull(image, platform: @options.platform)
          return if last.ok?
          break if last.err.match?(PERMANENT_PULL_FAILURE)

          @sleeper.call(5 * (attempt + 1)) if attempt < PULL_ATTEMPTS - 1
        end
        raise Failure, "can't pull #{image} (#{@plan[:tag] || "release unknown"}, #{@options.platform || "this platform"}) from #{image.split("/").first}: #{last.err.strip.lines.last.to_s.strip}"
      end

      def settle_version(labels)
        label = labels["org.opencontainers.image.version"].to_s
        flag = @options.previous_version
        version = flag || (label if label.match?(/\A\d+\.\d+\.\d+\z/))
        raise Failure, "the image's version label is #{label.inspect}, not a stable X.Y.Z; name the release with --previous-version X.Y.Z" unless version

        @out.puts "the image's label says #{label.inspect} and --previous-version says #{flag}; using #{flag}" if flag && label != flag
        @plan.merge!(version:, tag: "v#{version}", ref: "v#{version}")
      end

      def previous_database
        step("boot the previous release")
        @backups = File.join(@scratch, "backups")
        FileUtils.mkdir_p(@backups)
        @engine.own(@current, @backups)
        @volume = new_volume("a")
        instance = boot("previous", @plan[:image], @volume, SECRET, mounts: [ "#{@backups}:/backups" ])
        step("seed")
        @facts = run_seed(instance, @seed, where: @plan[:tag])
        step("before the stop")
        before_stop(instance)
        @backup_expected = backup_task?(instance)
        @backup_file = take_backup(instance) if @backup_expected
        step("stop and snapshot the old database")
        stop_and_snapshot(instance, "old").tap { verify_old(it) }
      end

      def run_seed(instance, path, where:)
        result = @engine.runner(instance.name, File.read(path))
        line = result.out.lines.reverse.find { it.start_with?(SEED_LINE) }
        unless result.ok? && line
          raise Failure, "#{File.basename(path)} failed on #{where} (status #{result.status}):\n#{(result.out + result.err).lines.last(40).join}"
        end

        JSON.parse(line.delete_prefix(SEED_LINE))
      end

      def before_stop(instance)
        @before = pages(@web.call(instance.port))
        raise Failure, "the previous instance shows no sign-up form, so the seed's open sign-up isn't visible: #{@before.inspect}" unless @before[:sign_up].last

        queued = marker_count(instance)
        raise Failure, "the seed's scheduled job (#{@facts["marker"]}) isn't in the queue: found #{queued}" unless queued == 1
      end

      def pages(web)
        signup = web.get("/registration/new")
        { up: web.status("/up"), sign_in: web.status("/session/new"), sign_up: [ signup.status, Web.signup_form?(signup.body) ] }
      end

      def stop_and_snapshot(instance, label)
        @engine.stop(instance.name)
        code = @engine.state(instance.name)[:exit_code]
        unless [ 0, 143 ].include?(code)
          raise Failure, "#{instance.name} stopped with status #{code}, not 0 or 143 (#{code == 137 ? "it was killed at the end of the grace period" : "it did not stop cleanly"}); no database was compared"
        end

        copies = File.join(@scratch, "copies", label)
        FileUtils.mkdir_p(copies)
        @engine.copy_database(volume: instance.volume, image: @current, into: copies)
        Snapshot.open(Snapshot.consolidate(copies, "production.sqlite3", File.join(@scratch, "#{label}.sqlite3")))
      end

      def verify_old(db)
        expected = @release.migration_versions(@plan[:ref]).sort
        actual = db.execute("SELECT version FROM schema_migrations").flatten.sort
        unless expected == actual
          raise Failure, "AC-2.1: schema_migrations of the old database isn't the versions of db/migrate at #{@plan[:tag]} (missing #{expected - actual}, extra #{actual - expected}); #{@plan[:image]} didn't make it"
        end

        problems, notes = SeedExceptions.coverage(db, @exceptions, label: @plan[:version] || "next", seed: relative(@seed))
        notes.each { @out.puts it }
        raise Failure, problems.join("\n") if problems.any?

        problems = Compare.seed_problems(db)
        raise Failure, problems.join("\n") if problems.any?
      end

      def upgrade(old)
        step("upgrade")
        instance = boot("upgrade", @current, @volume, SECRET)
        step("snapshot and compare")
        upgraded = stop_and_snapshot(instance, "upgraded")
        @engine.remove(instance.name)
        compare(old, upgraded)
      end

      # Prints the comparison; returns how many tables it covered.
      def compare(old, upgraded, optional: [], emptied: [])
        report = Compare.new(old, upgraded, expected: @changes.live, optional:, emptied:).call
        report.to_lines.each { @out.puts it }
        raise Failure, "the upgraded database differs from the old one (see above)" unless report.ok?

        problems = Compare.integrity(upgraded)
        raise Failure, "AC-3.5: #{problems.first(3).join("; ")}" if problems.any?

        missing = (working_versions + @release.migration_versions(@plan[:ref])) - upgraded.execute("SELECT version FROM schema_migrations").flatten
        raise Failure, "AC-3.2: schema_migrations of the upgraded database lacks #{missing}" if missing.any?

        report.lines.size
      end

      def behaviour_after_upgrade
        step("behaviour")
        check_behaviour(boot("behaviour", @current, @volume, SECRET), queue: true)
      end

      def check_behaviour(instance, queue:)
        webs = @facts["users"].to_h do |user|
          web = @web.call(instance.port)
          raise Failure, "AC-5.1: #{who(user)} couldn't sign in with their old password" unless web.sign_in(user["email"], @facts["password"])

          [ user["email"], web ]
        end
        owner = @facts["users"].find { it["lots"].positive? }
        empty = @facts["users"].find { it["lots"].zero? }
        check_collections(webs, owner, empty)
        after = pages(@web.call(instance.port))
        raise Failure, "AC-5.3: #{@before.inspect} before the stop, #{after.inspect} after" unless after == @before

        check_locations(webs.fetch(owner["email"]))
        check_export(webs.fetch(owner["email"]), owner)
        check_recurring(instance)
        check_queue(instance) if queue
      end

      def check_collections(webs, owner, empty)
        listed = webs.fetch(owner["email"]).get("/collection").body
        missing = owner["names"].reject { listed.include?(it) }
        raise Failure, "AC-5.2: #{who(owner)}'s collection page doesn't list #{missing.size} of the #{owner["names"].size} seeded names (first: position #{owner["names"].index(missing.first) + 1})" if missing.any?

        other = webs.fetch(empty["email"]).get("/collection")
        leaked = owner["names"].select { other.body.include?(it) }
        raise Failure, "AC-5.2: #{who(empty)}'s collection page answered #{other.status} and shows #{leaked.size} of another collector's seeded names" if other.status != 200 || leaked.any?
      end

      def check_locations(web)
        return if @facts["locations"].empty?

        body = web.get("/locations").body
        missing = @facts["locations"].reject { body.include?(it) }
        raise Failure, "AC-5.4: the locations page doesn't list #{missing.size} of the #{@facts["locations"].size} seeded locations" if missing.any?
      end

      # Failures name a collector by position and give counts, never an email, card or location name (spec 031 NFR Security).
      def who(user) = "collector #{@facts["users"].index(user) + 1} of #{@facts["users"].size}"

      def check_export(web, owner)
        response = web.get("/collection/export")
        raise Failure, "AC-5.5: /collection/export answered #{response.status}" unless response.status == 200

        document = JSON.parse(response.body)
        schema = File.join(@root, "app/models/export_format/v#{document["format_version"]}.schema.json")
        raise Failure, "AC-5.5: the export names format_version #{document["format_version"].inspect}, which this checkout has no schema for" unless File.file?(schema)

        errors = JSONSchemer.schema(JSON.parse(File.read(schema))).validate(document).first(3).map { it["error"] }
        raise Failure, "AC-5.5: the export doesn't validate against #{File.basename(schema)}: #{errors.join("; ")}" if errors.any?
        raise Failure, "AC-5.5: the export holds #{document["lots"].size} lots, the seed made #{owner["lots"]}" unless document["lots"].size == owner["lots"]
      end

      def check_recurring(instance)
        state = nil
        30.times do
          state = @engine.runner(instance.name, RECURRING).out.lines.last.to_s.strip
          break if state == "true"

          @sleeper.call(2)
        end
        raise Failure, "AC-5.6: the production recurring tasks of config/recurring.yml aren't all registered (got #{state.inspect})" unless state == "true"
      end

      def check_queue(instance)
        count = marker_count(instance)
        raise Failure, "AC-5.7: the scheduled job #{@facts["marker"]} is no longer in the queue (found #{count})" unless count == 1

        queued = @engine.runner(instance.name, ENQUEUE).out.lines.last.to_s.strip
        raise Failure, "AC-5.7: a job enqueued on the upgraded instance has no row in solid_queue_jobs (got #{queued.inspect})" unless queued == "true"
      end

      def marker_count(instance)
        @engine.runner(instance.name, %(puts SolidQueue::Job.where("arguments LIKE ?", "%#{@facts["marker"]}%").count)).out.lines.last.to_s.strip.to_i
      end

      def backup_task?(instance) = @engine.tasks(instance.name).out.include?("backup:create")

      # Takes the backup while the previous instance runs, into the directory mounted at /backups (decision 7).
      def take_backup(instance)
        result = @engine.task(instance.name, "backup:create[/backups]")
        unless result.ok? && result.out.include?("Backup written: /backups/collector-backup-")
          raise Failure, "backup:create failed on #{@plan[:tag]}:\n#{(result.out + result.err).strip}"
        end

        files = @engine.list_directory(@current, @backups)
        raise Failure, "the backup directory should hold exactly one file; it holds: #{files.inspect}" unless files.size == 1

        files.first
      end

      # Skipped only when the previous release lists no backup task (AC-6.4). Otherwise the backup it took is restored by the
      # code under test onto a fresh volume under another secret, and the database is judged as the upgrade's is, except that
      # the sessions the restore ends are expected gone (P4) and AC-5.7 doesn't apply (the backup holds the primary only).
      def backup_leg(old)
        step("backup leg")
        return @out.puts("previous release #{@plan[:tag]} has no backup task; backup leg skipped") unless @backup_expected

        volume = new_volume("restored")
        result = @engine.restore(image: @current, volume:, directory: @backups, file: @backup_file)
        raise Failure, "AC-6.3: backup:restore refused the backup #{@plan[:tag]} took: #{(result.out + result.err).strip.lines.last}" unless result.ok?

        instance = boot("restored", @current, volume, RESTORE_SECRET)
        restored = stop_and_snapshot(instance, "restored")
        @engine.remove(instance.name)
        compare(old, restored, optional: ExpectedChanges.restore_effects, emptied: ExpectedChanges::RESTORE_ENDS_SESSIONS)
        check_behaviour(boot("restored-behaviour", @current, volume, RESTORE_SECRET), queue: false)
      end

      def next_release
        step("seed of the next release")
        seed = File.join(@root, "script/upgrade/seeds/next.rb")
        raise Failure, "script/upgrade/seeds/next.rb is missing; releasing renames it, so a new one must be added (docs/releasing.md)" unless File.file?(seed)

        instance = boot("next", @current, new_volume("next"), SECRET)
        run_seed(instance, seed, where: "the code under test")
        database = stop_and_snapshot(instance, "next")
        exceptions = SeedExceptions.load(File.join(@root, "script/upgrade/seed_exceptions.yml"), "next")
        raise Failure, exceptions.errors.join("; ") if exceptions.errors.any?

        problems, notes = SeedExceptions.coverage(database, exceptions.entries, label: "next", seed: "script/upgrade/seeds/next.rb")
        notes.each { @out.puts it }
        raise Failure, problems.join("\n") if problems.any?

        problems = Compare.seed_problems(database)
        raise Failure, problems.join("\n") if problems.any?
      end

      # -- containers ----------------------------------------------------------------------------------------------

      def new_volume(label)
        name = "upgrade-smoke-#{@tag}-#{label}"
        @volumes << name
        @engine.create_volume(name)
        name
      end

      def boot(label, image, volume, secret, mounts: [])
        name = "upgrade-smoke-#{@tag}-#{label}"
        @containers << name
        @engine.start(name:, volume:, secret:, image:, mounts:)
        Instance.new(name, @engine.port(name), volume).tap { wait_for_up(it, label) }
      end

      def wait_for_up(instance, label)
        web = @web.call(instance.port)
        @options.boot_attempts.times do
          return if web.status("/up") == 200
          raise Failure, boot_failure(instance, label) unless @engine.state(instance.name)[:running]

          @sleeper.call(2)
        end
        raise Failure, "#{label}: /up did not answer 200 within #{@options.boot_attempts * 2} s\n#{@engine.logs(instance.name).lines.last(60).join}"
      end

      def boot_failure(instance, label)
        logs = @engine.logs(instance.name)
        migration = self.class.failed_migration(logs)
        about = migration ? " The last migration it began was #{migration}, upgrading the database of #{@plan[:tag]}." : ""
        "#{label}: the container exited before /up answered.#{about}\n#{logs.lines.last(60).join}"
      end

      def clean_up
        @containers.each { |name| quietly { @engine.remove(name) } }
        @volumes.each { |name| quietly { @engine.remove_volume(name) } }
        return unless @scratch

        quietly { @engine.remove_directory(@current, @scratch) }
        FileUtils.rm_rf(@scratch)
      end

      def quietly
        yield
      rescue StandardError
        nil
      end

      # -- reporting -----------------------------------------------------------------------------------------------

      def report_failure(message)
        @out.puts "FAIL: #{@step}: #{message}"
        @out.puts "  previous: #{@plan&.dig(:tag) || "not resolved"} #{@digest}"
        @out.puts "  commit: #{@release.head}"
        @out.puts "  read: the lines above; the container's log is printed where a boot failed"
        @out.puts "  reproduce: #{reproduce}"
        1
      end

      def reproduce
        flags = []
        flags += [ "--previous-ref", @plan[:ref] ] if @plan && !@plan[:release]
        flags += [ "--platform", @options.platform ] if @options.platform
        "bin/upgrade-smoke #{[ @plan&.dig(:image) || @previous_arg, @current, *flags ].join(" ")}"
      end

      def elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started).round

      def working_versions = Dir[File.join(@root, "db/migrate/*.rb")].filter_map { File.basename(it)[/\A\d+/] }

      def relative(path) = path.delete_prefix("#{@root}/")
  end
end
