# Every container command of the upgrade proof goes through this class (spec 031 AC-3.4, AC-8.3): a builder per command,
# one `run` that refuses anything a category does not accept and any database task, and an executor that a spec replaces.
require "fileutils"
require "json"
require "open3"

module Upgrade
  class Engine
    Failure = Class.new(StandardError)
    Result = Struct.new(:out, :err, :status) do
      def ok? = status.zero?
    end

    FORBIDDEN = %w[db:schema:load db:reset db:drop db:setup].freeze
    FILE_COMMANDS = %w[ls cp chown chmod rm].freeze
    ALLOWED = {
      pull: ->(args) { args.first == "pull" },
      inspect: ->(args) { args.first(2) == %w[image inspect] || (args.first == "inspect" && args[1] == "--format") },
      start: ->(args) { args.first(2) == %w[run -d] && args.include?("SOLID_QUEUE_IN_PUMA=true") && args.include?("127.0.0.1::8080") },
      observe: ->(args) { %w[port logs].include?(args.first) },
      stop: ->(args) { (args.first == "stop" && args[1] == "-t") || args.first(2) == %w[rm -f] },
      runner: ->(args) { args.first(2) == %w[exec -i] && args.last(3) == %w[bin/rails runner -] },
      tasks: ->(args) { args.first == "exec" && (args[3..] == %w[-T backup] || args[3].to_s.match?(%r{\Abackup:create\[/backups\]\z})) },
      restore: ->(args) { args.first(3) == %w[run --rm -u] && args.last.to_s.match?(%r{\Abackup:restore\[/backups/[\w.-]+\]\z}) },
      files: ->(command) { FILE_COMMANDS.include?(command.first) && (command.first != "rm" || command.drop(2).all? { it.start_with?("/work/") }) },
      volume: ->(args) { args.first == "volume" && %w[create rm].include?(args[1]) }
    }.freeze

    def self.detect = ENV["CONTAINER_CLI"] || (system("docker", "--version", out: File::NULL, err: File::NULL) ? "docker" : "podman")

    def initialize(cli: self.class.detect, run_flags: [], executor: nil)
      @cli = cli
      @run_flags = run_flags
      @executor = executor || method(:execute)
    end

    def pull(image, platform: nil) = run(:pull, [ "pull", *(platform ? [ "--platform", platform ] : []), image ])

    def image_info(image)
      result = run(:inspect, [ "image", "inspect", image ])
      JSON.parse(result.out).first if result.ok?
    end

    def create_volume(name) = run!(:volume, [ "volume", "create", name ])

    def remove_volume(name) = run(:volume, [ "volume", "rm", "-f", name ])

    def start(name:, volume:, secret:, image:, mounts: [])
      run!(:start, [ "run", "-d", "--name", name, *@run_flags, "-p", "127.0.0.1::8080", "-v", "#{volume}:/rails/storage",
        *mounts.flat_map { [ "-v", it ] }, "-e", "SECRET_KEY_BASE=#{secret}", "-e", "HTTP_PORT=8080", "-e", "SOLID_QUEUE_IN_PUMA=true", image ])
    end

    def port(name) = run!(:observe, [ "port", name, "8080" ]).out.lines.first.to_s[/:(\d+)\s*\z/, 1].to_i

    def state(name)
      running, code = run!(:inspect, [ "inspect", "--format", "{{.State.Running}} {{.State.ExitCode}}", name ]).out.split
      { running: running == "true", exit_code: code.to_i }
    end

    def logs(name) = run(:observe, [ "logs", name ]).then { it.out + it.err }

    def stop(name) = run!(:stop, [ "stop", "-t", "30", name ])

    def remove(name) = run(:stop, [ "rm", "-f", name ])

    # The seed, or a check, on standard input: `bin/rails runner -` evaluates it (railties-8.1.4 runner_command.rb).
    def runner(name, code) = run(:runner, [ "exec", "-i", name, "bin/rails", "runner", "-" ], stdin: code)

    def tasks(name) = run!(:tasks, [ "exec", name, "bin/rails", "-T", "backup" ])

    def task(name, task) = run(:tasks, [ "exec", name, "bin/rails", task ])

    def restore(image:, volume:, directory:, file:)
      run(:restore, [ "run", "--rm", "-u", "1000", *@run_flags, "-v", "#{volume}:/rails/storage", "-v", "#{directory}:/backups:ro",
        "-e", "SECRET_KEY_BASE_DUMMY=1", image, "bin/rails", "backup:restore[/backups/#{file}]" ])
    end

    # The primary database file and any -wal and -shm out of a stopped volume into a host directory (AC-2.4).
    def copy_database(volume:, image:, into:)
      listing = oneoff!(image, [ "#{volume}:/rails/storage:ro" ], %w[ls /rails/storage]).out.split
      files = listing.grep(/\Aproduction\.sqlite3(-wal|-shm)?\z/)
      raise Failure, "the volume #{volume} holds no production.sqlite3 (it holds: #{listing.join(" ")})" unless files.include?("production.sqlite3")

      oneoff!(image, [ "#{volume}:/rails/storage:ro", "#{into}:/out" ], [ "cp", "-p", *files.map { "/rails/storage/#{it}" }, "/out/" ])
      oneoff!(image, [ "#{into}:/out" ], %w[chmod -R a+rwX /out])
      files
    end

    def list_directory(image, directory) = oneoff!(image, [ "#{directory}:/backups:ro" ], %w[ls /backups]).out.split

    # What the container's user (uid 1000) writes can't be removed by the invoking user, nor can what a root one-off wrote.
    def own(image, directory)
      FileUtils.chmod(0o777, directory) unless oneoff(image, [ "#{directory}:/dir" ], %w[chown 1000:1000 /dir]).ok?
    end

    def remove_directory(image, directory) = oneoff(image, [ "#{directory}:/work" ], %w[rm -rf /work/copies /work/backups])

    private
      def oneoff(image, mounts, command)
        run(:files, [ "run", "--rm", "-u", "0", *@run_flags, *mounts.flat_map { [ "-v", it ] }, image, *command ], check: command)
      end

      def oneoff!(image, mounts, command)
        oneoff(image, mounts, command).tap { |result| raise Failure, "#{command.join(" ")} failed (status #{result.status}): #{result.err.strip}" unless result.ok? }
      end

      def run(category, args, check: args, stdin: nil)
        validator = ALLOWED.fetch(category) { raise Failure, "unknown command category #{category.inspect}" }
        if (args + Array(check)).any? { |argument| FORBIDDEN.any? { argument.include?(it) } }
          raise Failure, "refused: #{args.join(" ")} names a database task, which the proof never runs"
        end
        raise Failure, "refused: #{category} #{args.join(" ")} is not on the proof's list of commands" unless validator.call(check)

        @executor.call([ @cli, *args ], stdin)
      end

      def run!(category, args, **)
        run(category, args, **).tap do |result|
          raise Failure, "#{@cli} #{args.first(3).join(" ")} failed (status #{result.status}): #{result.err.strip}" unless result.ok?
        end
      end

      def execute(argv, stdin)
        out, err, status = Open3.capture3(*argv, stdin_data: stdin.to_s)
        Result.new(out, err, status.exitstatus || 128 + status.termsig.to_i)
      end
  end
end
