module CardScannerPhase2
  # The tuned knobs, shared by the page (served as /settings.json) and the Ruby side.
  module Settings
    module_function

    def load(path = SETTINGS_PATH) = JSON.parse(path.read)

    # The commit that last changed the settings file: the settings commit once tuning stops (AC-1.3).
    def commit(path = SETTINGS_PATH)
      IO.popen([ "git", "-C", REPO.to_s, "log", "-1", "--format=%H", "--", path.relative_path_from(REPO).to_s ], &:read).strip
    end
  end
end
