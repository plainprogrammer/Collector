require Rails.root.join("lib/collector/backup").to_s

# The operator's backup and restore (spec 030, ADR 0024, docs/backup-restore.md). Neither task depends on :environment, so
# neither initializes the application: no initializers, no queue or cache connection, no secret_key_base, and no Active
# Record connection that could create the primary's file (research.md 1 and 2). The logic is in lib/collector/backup/.
namespace :backup do
  desc %(Back up the primary database into DIRECTORY, an existing directory the container's user can write: bin/rails "backup:create[/backups]")
  task :create, [ :directory ] do |_task, args|
    Collector::Backup.run do
      directory = Collector::Backup.argument(args, :directory, 'bin/rails "backup:create[/path/to/directory]"')
      puts Collector::Backup::Create.new(directory:).call.report
    end
  end

  desc %(Restore a backup onto a fresh volume, before Collector's first start: bin/rails "backup:restore[/backups/collector-backup-20261021T142100Z.tar.gz]")
  task :restore, [ :file ] do |_task, args|
    Collector::Backup.run do
      file = Collector::Backup.argument(args, :file, 'bin/rails "backup:restore[/path/to/collector-backup.tar.gz]"')
      puts Collector::Backup::Restore.new(file:).call.report
    end
  end
end
