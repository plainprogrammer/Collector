require "rails_helper"
require "open3"
require "tmpdir"

# script/worktree/with_mise runs a command through `mise exec` where Orca's setup shell doesn't have mise
# on the PATH (#268). The fake mise only records its arguments and runs the command.
RSpec.describe "script/worktree/with_mise", type: :model do # rubocop:disable RSpec/DescribeClass -- a shell script, no class
  let(:dir) { File.realpath(Dir.mktmpdir) }
  let(:script) { Rails.root.join("script/worktree/with_mise").to_s }
  let(:base_path) { "/usr/bin:/bin" }

  after { FileUtils.remove_entry(dir) }

  def fake_mise(in_dir)
    FileUtils.mkdir_p(in_dir)
    File.join(in_dir, "mise").tap do |path|
      File.write(path, "#!/bin/sh\necho \"$@\" > \"#{dir}/mise-args.txt\"\nshift 2\nexec \"$@\"\n")
      File.chmod(0o755, path)
    end
  end

  def run_script(*args, env: {})
    Open3.capture3({ "PATH" => base_path, "HOME" => dir }.merge(env), script, *args)
  end

  def mise_args = File.exist?("#{dir}/mise-args.txt") ? File.read("#{dir}/mise-args.txt").strip : nil

  it "runs the command through mise on the PATH", :aggregate_failures do
    fake_mise(File.join(dir, "on-path"))
    out, _err, status = run_script("echo", "hi", env: { "PATH" => "#{dir}/on-path:#{base_path}" })
    expect([ status.success?, out.strip, mise_args ]).to eq([ true, "hi", "exec -- echo hi" ])
  end

  it "finds mise in a search directory when the PATH lacks it (#268)", :aggregate_failures do
    fake_mise(File.join(dir, "brew"))
    out, _err, status = run_script("echo", "hi", env: { "COLLECTOR_MISE_SEARCH" => "#{dir}/nope:#{dir}/brew" })
    expect([ status.success?, out.strip, mise_args ]).to eq([ true, "hi", "exec -- echo hi" ])
  end

  it "finds mise in ~/.local/bin by default" do
    fake_mise(File.join(dir, ".local/bin"))
    _out, _err, status = run_script("true")
    expect([ status.success?, mise_args ]).to eq([ true, "exec -- true" ])
  end

  it "fails with a message naming the search directories when mise is nowhere", :aggregate_failures do
    _out, err, status = run_script("true", env: { "COLLECTOR_MISE_SEARCH" => "#{dir}/nope" })
    expect(status.exitstatus).to eq(127)
    expect(err).to include("mise not found", "#{dir}/nope")
  end

  it "runs the command as it is with --optional when mise is nowhere", :aggregate_failures do
    out, _err, status = run_script("--optional", "echo", "hi", env: { "COLLECTOR_MISE_SEARCH" => "#{dir}/nope" })
    expect([ status.success?, out.strip, mise_args ]).to eq([ true, "hi", nil ])
  end

  it "passes the command's exit status through" do
    fake_mise(File.join(dir, "brew"))
    _out, _err, status = run_script("sh", "-c", "exit 3", env: { "COLLECTOR_MISE_SEARCH" => "#{dir}/brew" })
    expect(status.exitstatus).to eq(3)
  end

  # A login shell started from a terminal where mise was active keeps mise's directories, but after /usr/bin;
  # mise leaves a directory already in the PATH where it is, so the system Ruby would win (#268).
  describe "the PATH mise is given" do
    let(:data) { "#{dir}/.local/share/mise" }
    let(:fake) do
      fake_mise(File.join(dir, "brew")).tap do |path|
        File.write(path, "#!/bin/sh\necho \"$PATH\" > \"#{dir}/mise-path.txt\"\nshift 2\nexec \"$@\"\n")
      end
    end

    def path_seen = File.read("#{dir}/mise-path.txt").strip.split(":")

    it "drops mise's own install and shim directories so mise puts them first", :aggregate_failures do
      fake
      path = [ "/usr/bin", "#{data}/installs/ruby/4.0.7/bin", "/bin", "#{data}/shims", "#{data}/installs-not/bin" ].join(":")
      run_script("true", env: { "PATH" => path, "COLLECTOR_MISE_SEARCH" => "#{dir}/brew" })
      expect(path_seen).to eq([ "/usr/bin", "/bin", "#{data}/installs-not/bin" ])
    end

    it "follows MISE_DATA_DIR" do
      fake
      path = [ "/usr/bin", "#{dir}/data/installs/ruby/4.0.7/bin", "#{data}/shims" ].join(":")
      run_script("true", env: { "PATH" => path, "MISE_DATA_DIR" => "#{dir}/data", "COLLECTOR_MISE_SEARCH" => "#{dir}/brew" })
      expect(path_seen).to eq([ "/usr/bin", "#{data}/shims" ])
    end

    it "leaves the PATH alone when it runs the command without mise (--optional)" do
      path = [ "/usr/bin", "#{data}/shims", "/bin" ].join(":")
      out, _err, _status = run_script("--optional", "sh", "-c", "echo $PATH", env: { "PATH" => path, "COLLECTOR_MISE_SEARCH" => "#{dir}/nope" })
      expect(out.strip).to eq(path)
    end
  end
end
