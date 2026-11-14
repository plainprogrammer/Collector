# The licence check of spec 091: `bin/ci checks` runs it. It judges every gem of the bundle and every entry of the
# third-party manifest against config/licence_policy.yml, and reports spec 087's guard, so it needs the application.
namespace :licences do
  desc "Fail when a dependency is under a licence config/licence_policy.yml doesn't allow (spec 091); optional policy path"
  task :check, [ :policy ] => :environment do |_task, args|
    policy_path = Rails.root.join(args[:policy].presence || Collector::ThirdPartyLicences::Policy::PATH)
    begin
      check = Collector::ThirdPartyLicences::Check.for_repository(policy_path:)
      problems = check.problems
    rescue SystemCallError, Psych::Exception => error
      warn "Licences: can't read #{policy_path} or the licence manifest: #{error.message}"
      exit 1
    end

    if problems.any?
      warn "Licences: #{problems.size} problem#{"s" unless problems.one?}:", *problems.map { "  - #{it}" }
      exit 1
    end
    puts "Licences: #{check.component_count} components judged; each is under an allowed licence or a named exception."
  end
end
