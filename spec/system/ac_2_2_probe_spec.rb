# spec/system/ac_2_2_probe_spec.rb: temporary, reverted after Phase 6 step 4 (spec 035 AC-2.2, AC-2.3).
require "rails_helper"

RSpec.describe "Spec 035 AC-2.2 probe", type: :system do
  it "fails only on GitHub" do
    visit "/"
    expect(ENV["GITHUB_ACTIONS"]).to be_nil, "AC-2.2 probe"
  end
end
