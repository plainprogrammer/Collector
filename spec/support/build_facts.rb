# The running build's facts in specs (spec 084 decision 10). An example sets them with build_facts(...): raw values that
# go through Collector::BuildFacts.read's trimming and checking, as an image's environment would, read as production
# reads them (git is never asked). The boot reading comes back after the example.
module BuildFactsHelpers
  # Replaces the running build's facts for the rest of this example.
  #
  # @param version [String, nil] as `COLLECTOR_VERSION` would hold it
  # @param revision [String, nil] as `COLLECTOR_REVISION` would hold it
  # @param source_url [String, nil] as `COLLECTOR_SOURCE_URL` would hold it
  # @return [Collector::BuildFacts] the facts now in force
  def build_facts(version: nil, revision: nil, source_url: nil)
    @build_facts_at_boot = Rails.configuration.x.build_facts unless defined?(@build_facts_at_boot)
    env = { "COLLECTOR_VERSION" => version, "COLLECTOR_REVISION" => revision, "COLLECTOR_SOURCE_URL" => source_url }.compact
    Rails.configuration.x.build_facts = Collector::BuildFacts.read(env:, rails_env: "production")
  end

  # Puts back the facts read at boot, if this example replaced them; the suite calls it after every example.
  #
  # @return [void]
  def restore_build_facts
    Rails.configuration.x.build_facts = @build_facts_at_boot if defined?(@build_facts_at_boot)
  end
end

RSpec.configure do |config|
  config.include BuildFactsHelpers
  config.after { restore_build_facts }
end
