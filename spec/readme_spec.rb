require "rails_helper"

RSpec.describe "README" do
  let(:readme) { Rails.root.join("README.md").read }

  it "documents accounts and the new settings", :aggregate_failures do
    expect(readme).to include("collector:user", "COLLECTOR_HTTPS", "COLLECTOR_TRUSTED_PROXIES", "COLLECTOR_CURRENCY", "COLLECTOR_PASSWORD")
    expect(readme).to include("only acceptable on a trusted private network", "doesn't convert prices you've already entered")
  end

  it "lists libvips and ImageMagick with their packages (spec 014 AC-4.1)", :aggregate_failures do
    requirements = readme[/^## Requirements\n.*?(?=^## )/m].to_s
    expect(requirements).to include("libvips", "sudo dnf install vips", "sudo apt install libvips")
    expect(requirements).to include("ImageMagick", "sudo dnf install ImageMagick", "sudo apt install imagemagick")
  end

  it "warns about the first-run admin before the deployment steps", :aggregate_failures do
    expect(readme).to match(/first person to reach .* becomes its admin/i)
    expect(readme.index("Before you expose Collector")).to be < readme.index("### Docker Compose")
  end

  it "puts the upgrade warning before the upgrade steps" do
    upgrade = readme[/### Upgrading to accounts.*?(?=^## )/m]
    expect(upgrade.index("Read this before you upgrade")).to be < upgrade.index("1. Pull the new image")
  end

  it "documents the published image for Compose and Kamal (spec 012 AC-5.3, AC-7.3, AC-7.4)", :aggregate_failures do
    compose = readme[/^### Docker Compose\n.*?(?=^###)/m].to_s
    expect(compose).to include("COLLECTOR_IMAGE", "ghcr.io/plainprogrammer/collector", "docker compose pull && docker compose up -d",
                               "docker build -t collector:local .")
    expect(compose).not_to include("--build")
    kamal = readme[/^### Kamal\n.*?(?=^###)/m].to_s
    expect(kamal).to include("bin/kamal deploy --skip-push --version", "a registry you own", "Never run a plain `bin/kamal deploy`")
    expect(readme[/^### Card scanner\n.*?(?=^##)/m].to_s).to include("The published image already contains it")
    expect(readme).to include("docs/releasing.md")
    expect(readme).not_to include("pull the new code")
  end

  it "documents the card scanner's HTTPS needs for phones, Compose and Kamal (spec 007 AC-7.1, AC-7.2, AC-7.3)", :aggregate_failures do
    expect(readme).to include("RAILS_DEVELOPMENT_HOSTS", "bin/dev-certificate", "bin/fetch-ocr-engine", "COLLECTOR_SCANNER_MANIFEST", "COLLECTOR_REQUEST_LOG")
    scanner = readme[/^### Card scanner\n.*?(?=^##)/m].to_s
    expect(scanner).to include("HTTPS", "only the photo picker works", "Docker Compose", "Kamal", "ssl: true", "registry.npmjs.org")
  end

  it "documents opt-in art matching in the README, Compose and Kamal (spec 011 AC-1.3)", :aggregate_failures do
    art = readme[/^- \*\*Art matching \(optional\):\*\*.*?(?=^- \*\*|^## )/m].to_s
    expect(readme).to include("| `COLLECTOR_MTG_ART_MATCHING`")
    expect(art).to include("COLLECTOR_MTG_ART_MATCHING", "about 708 MB", "about 2.6 hours", "about 7.3 MB",
      'bin/rails "catalog:refresh[mtg]"', "storage/catalog/mtg/art", "text alone")
    expect(Rails.root.join("compose.yaml").read).to include('COLLECTOR_MTG_ART_MATCHING: "${COLLECTOR_MTG_ART_MATCHING:-}"')
    expect(Rails.root.join("config/deploy.yml").read).to include("# COLLECTOR_MTG_ART_MATCHING: true")
  end
end
