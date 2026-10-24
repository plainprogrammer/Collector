require "rails_helper"
require "open3"
require "rbconfig"
require Rails.root.join("script/upgrade/guard").to_s

RSpec.describe Upgrade::Guard, :git_sandbox, :upgrade do
  let(:dir) { upgrade_dir }
  let(:actions) { { "GITHUB_ACTIONS" => "true", "GITHUB_REF_TYPE" => "branch" } }
  let(:first) { "db/migrate/20261001000001_create_a.rb" }
  let(:second) { "db/migrate/20261001000002_create_b.rb" }

  def guard = described_class.new(Upgrade::Release.new(dir, env: actions), root: dir).call

  def release_with_two_migrations
    build_history(dir, "v0.2.0" => { first => "class CreateA; end\n", second => "class CreateB; end\n" })
  end

  it "passes when every released migration is unchanged and a new one was added (AC-8.1)" do
    release_with_two_migrations
    File.write(File.join(dir, "db/migrate/20261002000001_create_c.rb"), "class CreateC; end\n")
    expect(guard).to be_ok
  end

  it "fails naming an edited migration and saying a new migration is the fix (AC-8.2)", :aggregate_failures do
    release_with_two_migrations
    File.write(File.join(dir, first), "class CreateA; def change; end; end\n")
    result = guard
    expect(result).not_to be_ok
    expect(result.lines.join("\n")).to include(first, "v0.2.0", "never edited or deleted", "new migration")
  end

  it "fails naming a deleted migration (AC-8.2)" do
    release_with_two_migrations
    File.delete(File.join(dir, second))
    expect(guard.lines.join("\n")).to include("#{second} was deleted or renamed since v0.2.0")
  end

  it "fails naming a renamed migration (AC-8.2)" do
    release_with_two_migrations
    git!(dir, "mv", second, "db/migrate/20261001000003_create_b.rb")
    git!(dir, "commit", "-q", "-m", "rename")
    expect(guard.lines.join("\n")).to include("#{second} was deleted or renamed")
  end

  it "says the code under test is behind the release when a branch lacks a released migration (AC-8.4)", :aggregate_failures do
    build_history(dir, "v0.1.0" => { first => "a\n" }, "v0.2.0" => { second => "b\n" })
    git!(dir, "checkout", "-q", "v0.1.0")
    result = guard
    expect(result).not_to be_ok
    expect(result.lines.join("\n")).to include("the code under test is behind v0.2.0", second)
  end

  it "passes with a line saying there is no previous release when no tag is stable (AC-8.5)", :aggregate_failures do
    build_history(dir, "v0.1.0-rc.1" => { first => "a\n" })
    expect(guard).to be_ok
    expect(guard.lines.join).to include("no previous release")
  end

  it "fails saying to fetch tags when the checkout has a remote and no tags (AC-8.5)", :aggregate_failures do
    build_history(dir, "work" => { first => "a\n" })
    git!(dir, "remote", "add", "origin", "https://example.invalid/collector.git")
    expect(guard).not_to be_ok
    expect(guard.lines.join).to match(/fetch/i)
  end

  it "fails with a message, not a backtrace, when the ref names no release (AC-8.1, Error Scenarios)", :aggregate_failures do
    release_with_two_migrations
    guard = described_class.new(Upgrade::Release.new(dir, env: { "GITHUB_ACTIONS" => "true", "GITHUB_REF_TYPE" => "tag", "GITHUB_REF_NAME" => "nightly" }), root: dir)
    expect(guard.call).not_to be_ok
  end

  it "runs as a script: prints the lines and exits non-zero on a failure (AC-8.1)", :aggregate_failures do
    release_with_two_migrations
    File.write(File.join(dir, first), "edited\n")
    out, _err, status = Open3.capture3({ "GITHUB_ACTIONS" => "true", "GITHUB_REF_TYPE" => "branch", "GITHUB_REF_NAME" => "main" }, RbConfig.ruby, Rails.root.join("script/upgrade/guard.rb").to_s, chdir: dir)
    expect(status.exitstatus).to eq(1)
    expect(out).to include(first)
  end
end
