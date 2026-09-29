require "zlib"

module Collector
  # Dev server port per checkout (spec 003, FR-5): 3000 in the main checkout, a
  # stable 3001–3999 port in a linked worktree, PORT always wins. Stdlib only:
  # loaded by config/puma.rb and bin/setup before the app boots.
  module DevPort
    DEFAULT = 3000
    WORKTREE_RANGE = (3001..3999)

    module_function

    def resolve(root:, env: ENV)
      return Integer(env["PORT"]) if env["PORT"] && !env["PORT"].empty?
      return DEFAULT unless env.fetch("RAILS_ENV", "development") == "development"
      # A linked worktree's .git is a file pointing at the shared git dir.
      return DEFAULT unless File.file?(File.join(root, ".git"))

      for_worktree(File.realpath(root))
    end

    def for_worktree(path)
      WORKTREE_RANGE.first + (Zlib.crc32(path) % WORKTREE_RANGE.size)
    end
  end
end
