require "rails_helper"

# Spec 038 decision 2, FR-4: no price code reads the instance default. A renamed key would answer empty options (a nil
# symbol, so `$`), so the reads are removed and checked here instead.
RSpec.describe "Reads of the instance currency" do
  let(:files) { Dir.glob(Rails.root.join("{app,lib,config}/**/*.{rb,erb}")).map { |path| Pathname(path).relative_path_from(Rails.root).to_s } }
  let(:allowed) { %w[app/models/account.rb config/initializers/currency.rb] }

  it "are left to Account and the initializer", :aggregate_failures do
    offenders = files.reject { |file| allowed.include?(file) }.select { |file| Rails.root.join(file).read.match?(/\bx\.(default_)?currency\b/) }
    expect(offenders).to be_empty
    expect(Rails.root.join("config/initializers/currency.rb").read).not_to match(/\bx\.currency\b/)
  end
end
