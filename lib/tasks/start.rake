require Rails.root.join("lib/collector/start_check").to_s

# The container's start check (spec 086): bin/docker-entrypoint runs it before db:prepare on a server start. It has no
# :environment prerequisite, so it initializes nothing: no initializer, no database connection that could create a
# primary, no secret_key_base. Nothing but the entrypoint calls it.
namespace :start do
  desc "Refuse a start on a volume that holds the prices database and no primary (exit 1 with the reason)"
  task :check do
    lines = Collector::StartCheck.refusal
    next unless lines

    warn(*lines)
    exit 1
  end
end
