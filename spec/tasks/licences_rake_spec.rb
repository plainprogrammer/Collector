require "rails_helper"
require "rake"
require "tmpdir"

# Spec 091 FR-3, AC-4.2 and AC-4.3. The step judges the repository's own policy in `bin/ci checks` (evidence in verification.md);
# here the task runs in-process, so a licence change in the bundle can't take a shard down: the passing run uses a policy that
# allows every licence the list declares, the failing one a policy that allows nothing.
RSpec.describe "licences rake task", type: :task do # rubocop:disable RSpec/DescribeClass -- rake tasks have no class
  before { Rails.application.load_tasks unless Rake::Task.task_defined?("licences:check") }

  after { Rake::Task["licences:check"].reenable }

  # Runs the task with its output captured and `exit` rescued (RSpec doesn't rescue SystemExit, so an unrescued exit would end
  # the whole process), as [standard output, standard error, exit status].
  def run_check(*args)
    out = StringIO.new
    err = StringIO.new
    original = [ $stdout, $stderr ]
    $stdout, $stderr = out, err
    status = begin
      Rake::Task["licences:check"].invoke(*args)
      0
    rescue SystemExit => error
      error.status
    end
    [ out.string, err.string, status ]
  ensure
    $stdout, $stderr = original
  end

  def with_policy(yaml)
    Dir.mktmpdir("licence-policy") do |dir|
      file = File.join(dir, "policy.yml")
      File.write(file, yaml)
      yield file
    end
  end

  def allow_everything_yaml
    ids = Collector::ThirdPartyLicences.build.sections.flat_map(&:components).flat_map(&:identifiers).uniq
    { "allowed" => ids.map { { "id" => it, "reason" => "a fixture" } }, "exceptions" => [] }.to_yaml
  end

  it "exits 0 and prints how many components it judged on standard output (AC-4.2)", :aggregate_failures do
    with_policy(allow_everything_yaml) do |file|
      out, err, status = run_check(file)

      expect(status).to eq(0)
      expect(out).to match(/Licences: \d+ components judged/)
      expect(err).to be_empty
    end
  end

  it "exits 1 against a policy that allows nothing, printing each dependency, its licence and the file on standard error (AC-4.3)", :aggregate_failures do
    with_policy("allowed: []\nexceptions: []\n") do |file|
      _out, err, status = run_check(file)

      expect(status).to eq(1)
      expect(err).to include("gem rake", "MIT", file)
      expect(err.lines.size).to be > 100
    end
  end

  it "exits 1 naming the file when it can't be read", :aggregate_failures do
    _out, err, status = run_check("/nonexistent/policy.yml")

    expect(status).to eq(1)
    expect(err).to include("/nonexistent/policy.yml")
  end
end
