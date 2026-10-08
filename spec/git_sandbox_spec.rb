require "rails_helper"
require "tmpdir"

RSpec.describe GitSandbox, :git_sandbox do
  let(:dir) { File.realpath(Dir.mktmpdir) }

  after { FileUtils.remove_entry(dir) }

  # A commit can start automatic maintenance in a detached process that outlives it and holds
  # .git/objects/maintenance.lock; removing the sandbox then races that process (ENOENT on CI, 2026-10-08).
  it "switches off automatic maintenance in sandbox repositories" do
    expect(git!(new_repo(File.join(dir, "main")), "config", "--get", "maintenance.auto")).to eq("false\n")
  end
end
