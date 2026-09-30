require "rails_helper"

RSpec.describe "README" do
  let(:readme) { Rails.root.join("README.md").read }

  it "documents accounts and the new settings", :aggregate_failures do
    expect(readme).to include("collector:user", "COLLECTOR_HTTPS", "COLLECTOR_TRUSTED_PROXIES", "COLLECTOR_CURRENCY", "COLLECTOR_PASSWORD")
    expect(readme).to include("only acceptable on a trusted private network", "doesn't convert prices you've already entered")
  end

  it "warns about the first-run admin before the deployment steps", :aggregate_failures do
    expect(readme).to match(/first person to reach .* becomes its admin/i)
    expect(readme.index("Before you expose Collector")).to be < readme.index("### Docker Compose")
  end

  it "puts the upgrade warning before the upgrade steps" do
    upgrade = readme[/### Upgrading to accounts.*?(?=^## )/m]
    expect(upgrade.index("Read this before you upgrade")).to be < upgrade.index("1. Pull the new code.")
  end
end
