require "open3"

module Collector
  module Backup
    # The bytes available to the user on the filesystem that holds a path, from `df` (POSIX output, 1024-byte blocks).
    # nil when it can't be read: the free-space checks (AC-1.11, decision 13) are then skipped rather than guessed.
    module FreeSpace
      def self.bytes(path)
        output, status = Open3.capture2e("df", "-Pk", path.to_s)
        return unless status.success?

        available = output.lines.last.to_s.split[3]
        available && Integer(available, 10) * 1024
      rescue Errno::ENOENT, ArgumentError
        nil
      end
    end
  end
end
