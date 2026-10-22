module Collector
  module Backup
    # Where this environment's databases live: the files that make a volume "not fresh" (decision 6) and the path of the
    # primary. Read from config/database.yml without a connection pool, so it works before the application is initialized.
    class Databases
      SIDECARS = [ "", "-wal", "-shm", "-journal" ].freeze

      def self.configured(env: Rails.env)
        configs = ActiveRecord::DatabaseConfigurations.new(Rails.application.config.database_configuration).configs_for(env_name: env.to_s)
        new(configs.to_h { |config| [ config.name, Rails.root.join(config.database) ] })
      end

      def initialize(paths)
        @paths = paths.transform_values { Pathname(it) }
      end

      def names = @paths.keys
      def primary = @paths.fetch("primary")
      def directory = primary.dirname

      # Every file of the four databases that exists, a stale -wal or -journal included: a -wal beside a restored
      # database would be replayed into it, and an old queue database would run old jobs against it (decision 6).
      def occupied
        @paths.values.flat_map { |path| SIDECARS.map { Pathname("#{path}#{it}") } }.select { it.exist? || it.symlink? }
      end
    end
  end
end
