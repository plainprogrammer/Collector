require "open3"

# Throwaway git repositories for worktree specs (spec 003). Isolated from the
# developer's git config and from any GIT_* variables of an enclosing hook.
module GitSandbox
  ENV_OVERRIDES = {
    "GIT_CONFIG_GLOBAL" => File::NULL, "GIT_CONFIG_NOSYSTEM" => "1",
    "GIT_DIR" => nil, "GIT_WORK_TREE" => nil, "GIT_INDEX_FILE" => nil, "GIT_COMMON_DIR" => nil,
    "GIT_AUTHOR_NAME" => "Spec", "GIT_AUTHOR_EMAIL" => "spec@example.test",
    "GIT_COMMITTER_NAME" => "Spec", "GIT_COMMITTER_EMAIL" => "spec@example.test",
    # No automatic maintenance: a detached run outlives the command and races the sandbox's removal.
    "GIT_CONFIG_COUNT" => "1", "GIT_CONFIG_KEY_0" => "maintenance.auto", "GIT_CONFIG_VALUE_0" => "false"
  }.freeze

  def git(dir, *args, env: {})
    Open3.capture3(ENV_OVERRIDES.merge(env), "git", *args, chdir: dir)
  end

  def git!(dir, *args, env: {})
    out, err, status = git(dir, *args, env: env)
    raise "git #{args.join(' ')} failed: #{err}" unless status.success?
    out
  end

  # A main checkout with a .gitignore and .worktreeinclude for the two secrets.
  def new_repo(dir, extra_files: {})
    FileUtils.mkdir_p(File.join(dir, "tmp"))
    files = {
      ".gitignore" => "/config/*.key\n/tmp/*\n!/tmp/.keep\n",
      ".worktreeinclude" => "config/master.key\ntmp/local_secret.txt\n",
      "tmp/.keep" => ""
    }.merge(extra_files)
    files.each do |path, body|
      FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
      File.write(File.join(dir, path), body)
    end
    git!(dir, "init", "-q", "-b", "main")
    git!(dir, "add", ".")
    git!(dir, "commit", "-q", "-m", "init")
    dir
  end
end

RSpec.configure { |config| config.include GitSandbox, :git_sandbox }
