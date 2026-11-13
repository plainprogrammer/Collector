require Rails.root.join("script/upgrade/engine").to_s
require Rails.root.join("script/upgrade/web").to_s

# An Upgrade::Engine that runs nothing: it records each call and answers from DEFAULTS, overridden per example by
# keyword (a value, or a callable that gets the call's arguments). Spec 031 AC-8.6.
class FakeEngine
  Result = Upgrade::Engine::Result
  SEED_LINE = "UPGRADE-SEED-COMPLETE ".freeze
  # What a started instance's log holds once Solid Queue's three processes are up (the harness waits for these before it stops).
  QUEUE_STARTED = <<~LOG.freeze
    SolidQueue-1.7.0 Started Supervisor(fork) (9.0ms)  pid: 33
    SolidQueue-1.7.0 Started Dispatcher (30.0ms)  pid: 40
    SolidQueue-1.7.0 Started Worker (30.0ms)  pid: 44
    SolidQueue-1.7.0 Started Scheduler (70.0ms)  pid: 48
  LOG
  FACTS = { "release" => "0.2.1", "password" => "pw-1234-pw-1234", "marker" => "upgrade-marker", "locations" => [],
    "users" => [ { "email" => "ada@x.test", "lots" => 2001, "names" => [ "Dragon One", "Dragon Two" ] }, { "email" => "grace@x.test", "lots" => 0, "names" => [] } ] }.freeze
  DEFAULTS = {
    pull: Result.new("", "", 0),
    image_info: { "RepoDigests" => [ "ghcr.io/plainprogrammer/collector@sha256:abc123" ],
      "Config" => { "Labels" => { "org.opencontainers.image.version" => "0.2.1", "org.opencontainers.image.revision" => "deadbeef" } } },
    create_volume: nil, remove_volume: nil, start: nil, port: 4000, state: { running: true, exit_code: 0 }, stop: nil, logs: QUEUE_STARTED, remove: nil,
    tasks: Result.new("", "", 0), task: Result.new("Backup written: /backups/collector-backup-1.tar.gz\n", "", 0),
    restore: Result.new("Restored collector-backup-1.tar.gz into /rails/storage.\n", "", 0), list_directory: [ "collector-backup-1.tar.gz" ],
    own: nil, remove_directory: nil
  }.freeze

  attr_reader :calls

  # `databases`: what copy_database hands out, in order (old, upgraded, ...): a path to a primary database, or a Hash
  # `{ primary:, prices: }` with the prices database's path too (spec 081 AC-6.4); `log` receives each call's name;
  # `facts`: what the seed reports; `runner_answers`: { /code pattern/ => Result } consulted before the defaults.
  def initialize(databases: [], log: [], facts: FACTS, runner_answers: {}, **scripted)
    @databases = databases.dup
    @log = log
    @facts = facts
    @runner_answers = runner_answers
    @scripted = scripted
    @calls = []
  end

  def names = @calls.map(&:first)

  def runner(name, code)
    record(:runner, [ name, code ], {}) { default_runner(code) }
  end

  # Copies the next entry of `databases` into `into` as `production.sqlite3` and, when the entry carries one, the prices
  # database as `production_prices.sqlite3`; returns the names it copied, as Upgrade::Engine#copy_database does.
  def copy_database(volume:, image:, into:)
    record(:copy_database, [], { volume:, image:, into: }) do
      entry = @databases.shift || raise("no database left for copy_database")
      entry = { primary: entry } unless entry.is_a?(Hash)
      FileUtils.cp(entry.fetch(:primary), File.join(into, "production.sqlite3"))
      names = [ "production.sqlite3" ]
      if entry[:prices]
        FileUtils.cp(entry[:prices], File.join(into, "production_prices.sqlite3"))
        names << "production_prices.sqlite3"
      end
      names
    end
  end

  (Upgrade::Engine.public_instance_methods(false) - %i[runner copy_database]).each do |method|
    define_method(method) do |*args, **kwargs|
      record(method, args, kwargs) { DEFAULTS.fetch(method) }
    end
  end

  private
    def record(method, args, kwargs)
      @calls << [ method, args, kwargs ]
      @log << method
      answer = @scripted.key?(method) ? @scripted[method] : yield
      answer.respond_to?(:call) ? answer.call(*args, **kwargs) : answer
    end

    # The seed, the marker count, the recurring check and the enqueue check, told apart by their code.
    def default_runner(code)
      answer = @runner_answers.find { |pattern, _| code.match?(pattern) }&.last
      return answer.respond_to?(:call) ? answer.call : answer if answer

      case code
      when /fake seed/ then Result.new("#{SEED_LINE}#{JSON.generate(@facts)}\n", "", 0)
      when /RecurringTask|perform_later/ then Result.new("true\n", "", 0)
      else Result.new("1\n", "", 0)
      end
    end
end

# Upgrade::Web with pages scripted per path (a Response, or a callable that gets the signed-in user's email or nil). Each
# client the harness makes remembers who signed in. Fetching a page is logged as :get, a sign-in as :sign_in; the /up poll
# and the status reads are not logged.
class FakeWeb
  Response = Upgrade::Web::Response

  class Client
    def initialize(web)
      @web = web
      @user = nil
    end

    def get(path) = @web.fetch(path, @user, logged: true)

    def status(path) = @web.fetch(path, @user, logged: false).status

    def sign_in(email, _password)
      @web.log << :sign_in
      @user = email if @web.sign_in_ok
      @web.sign_in_ok
    end
  end

  attr_accessor :sign_in_ok
  attr_reader :log

  def initialize(pages: {}, log: [])
    @pages = pages
    @log = log
    @sign_in_ok = true
  end

  def new_client(_port) = Client.new(self)

  def fetch(path, user, logged:)
    @log << :get if logged
    answer = @pages.fetch(path) { Response.new(200, "") }
    answer.respond_to?(:call) ? answer.call(user) : answer
  end
end
