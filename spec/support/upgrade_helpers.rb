require "fileutils"
require "sqlite3"
require "tmpdir"

# Throwaway repositories and databases for spec 031's examples (tag a group :upgrade, and :git_sandbox when it needs git!).
module UpgradeHelpers
  def upgrade_dir = @upgrade_dir ||= File.realpath(Dir.mktmpdir("upgrade-spec"))

  # Commits each step in turn: { "message" => { "path" => "body" } }. A message that starts with "v" also tags the commit.
  def build_history(dir, steps)
    FileUtils.mkdir_p(dir)
    git!(dir, "init", "-q", "-b", "main")
    steps.each do |message, files|
      files.each do |path, body|
        FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
        File.write(File.join(dir, path), body)
      end
      git!(dir, "add", "-A")
      git!(dir, "commit", "-q", "--allow-empty", "-m", message)
      git!(dir, "tag", message) if message.start_with?("v")
    end
    dir
  end

  # A SQLite database at `path`, built by the block (which gets the open connection) and closed.
  def build_database(path)
    database = SQLite3::Database.new(path)
    yield database
    database.close
    path
  end

  def open_database(path) = SQLite3::Database.new(path, readonly: true)
end

RSpec.configure do |config|
  config.include UpgradeHelpers, :upgrade
  config.after(:each, :upgrade) { FileUtils.remove_entry(@upgrade_dir) if @upgrade_dir && File.exist?(@upgrade_dir) }
end
