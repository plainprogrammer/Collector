require_relative "backup/databases"

module Collector
  # The container's start check (spec 086): decides, from which database files are on the volume, whether a server start
  # may go on, and words the refusal. A prices file or one of its sidecars with no primary is the state a +backup:restore+
  # killed between its two placings leaves, and a start on it would create a blank primary and keep prices that the new
  # catalog's printings don't own (spec 081 decision 8). It asks the file system for existence and size only: it opens no
  # database, creates no file and needs no secret, a connection or the application's initializers.
  #
  # A primary is *there* when it exists following a symlink and isn't empty: a dangling link or an empty file isn't one
  # (spec 086 decision 7). The prices file and each sidecar count when they exist or are symlinks, dangling or not, as
  # the restore counts them (+Backup::Databases#occupied+).
  # @see file:release-and-deploy.md
  class StartCheck
    # The refusal of the volume Collector would start on, or nil when the start may go on.
    #
    # @param databases [Backup::Databases] where the files are; the configured ones by default
    # @return [Array<String>, nil] the lines to print on standard error
    def self.refusal(databases: Backup::Databases.configured) = new(databases:).refusal

    # @param databases [Backup::Databases]
    def initialize(databases:)
      @databases = databases
    end

    # The three sentences that refuse this volume, or nil when the start may go on.
    #
    # @return [Array<String>, nil]
    def refusal
      return unless @databases.prices

      prices = present(@databases.prices)
      return if prices.empty? || primary_there?

      lines(prices, present(@databases.primary))
    end

    private
      def primary_there? = @databases.primary.exist? && @databases.primary.size.positive?

      # The files among a database's file and its sidecars that exist or are links.
      def present(path) = Backup::Databases::SIDECARS.map { Pathname("#{path}#{it}") }.select { it.exist? || it.symlink? }

      # What a leftover primary file is, for the message: a broken link, a sidecar left behind, or an empty file.
      def kind(path)
        return "a broken link" if path.symlink? && !path.exist?

        path.to_s == @databases.primary.to_s ? "an empty file" : "a sidecar left behind"
      end

      def lines(prices, leftovers)
        names = leftovers.map { it.basename.to_s }
        instead = leftovers.empty? ? "" : " (it holds #{leftovers.map { "#{it.basename}, #{kind(it)}" }.join("; ")} instead, which is not a database)"
        removal = [ "#{@databases.prices.basename} and its -wal, -shm and -journal files", *names ].then { it.size > 2 ? "#{it[..-2].join(", ")} and #{it.last}" : it.join(" and ") }
        [ "Collector did not start: the storage directory #{@databases.directory} holds #{prices.join(", ")} and no primary database#{instead}.",
          "A backup:restore that stopped between placing the prices database and the primary leaves this state. Starting here would create a blank primary and keep these prices, which the new catalog's printings don't own.",
          "Remove #{removal}, then restore again onto a volume that holds no other Collector database, or start Collector blank. Run nothing else on the volume meanwhile. Nothing was changed." ]
      end
  end
end
