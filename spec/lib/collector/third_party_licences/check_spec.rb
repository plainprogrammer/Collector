require "rails_helper"
require "tmpdir"

# Spec 091 decision 7, AC-4.4: Check joins an injected audit's problems and the policy's, the guard's first.
RSpec.describe Collector::ThirdPartyLicences::Check, type: :model do
  def policy_reporting(*problems) = instance_double(Collector::ThirdPartyLicences::Policy, problems:, component_count: 3)

  def audit_reporting(*problems) = instance_double(Collector::ThirdPartyLicences::Audit, problems:)

  it "lists the audit's problems first and the policy's second, and counts the components the policy judged", :aggregate_failures do
    check = described_class.new(audit: audit_reporting("pin has no entry"), policy: policy_reporting("gem x is under GPL"))

    expect(check.problems).to eq([ "pin has no entry", "gem x is under GPL" ])
    expect(check.component_count).to eq(3)
  end

  it "carries the guard's sentence for an importmap pin with no manifest entry (decision 7)" do
    pin = Collector::ThirdPartyLicences::Audit::Pin.new(name: "lodash", asset: "/x/vendor/javascript/lodash.js")
    audit = Collector::ThirdPartyLicences::Audit.new(manifest: {}, text_dir: Dir.tmpdir, specs: [], ocr_digests: [], pins: [ pin ],
      pin_directories: [], app_javascript: "/x/app/javascript", font_files: {}, icon_files: [])

    expect(described_class.new(audit:, policy: policy_reporting).problems).to eq([ "importmap pin lodash has no javascript entry" ])
  end
end
