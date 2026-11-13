# Spec 084: the running build's facts (Collector::BuildFacts), read once at boot so that git, which a development
# checkout asks for its revision, never runs during a request. after_initialize, because the reader is autoloaded from
# lib/ and can't be referenced while the configuration loads. Tests never read the environment (a developer's exported
# variable mustn't change a page in the suite); examples set the facts with build_facts(...) (spec/support/build_facts.rb).
Rails.application.config.after_initialize do
  Rails.configuration.x.build_facts = Collector::BuildFacts.read(env: Rails.env.test? ? {} : ENV, rails_env: Rails.env)
end
