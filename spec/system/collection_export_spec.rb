require "rails_helper"

# Spec 022 AC-3.3: the account menu's "Export collection" downloads the file and leaves the collection page shown.
RSpec.describe "Collection export", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }

  before do
    FileUtils.rm_rf(DOWNLOADS)
    FileUtils.mkdir_p(DOWNLOADS)
  end

  # Capybara has no download matcher; its own waiting retries until the file is complete, bounded at 10 seconds and
  # never a sleep (AC-3.3), as spec/system/scanner_measurement_spec.rb waits for its events.
  def downloaded(name)
    file = DOWNLOADS.join(name)
    part = DOWNLOADS.join("#{name}.part")
    page.document.synchronize(10) { raise Capybara::ExpectationNotMet, "no #{name}" unless file.exist? && file.size.positive? && !part.exist? }
    file
  end

  it "downloads the collection from the account menu", :aggregate_failures do
    create(:lot, account: user.account, entry: create(:mtg_printing).entry, finish: "foil")
    visit collection_path
    name = "collector-export-#{Time.current.utc.to_date.iso8601}.json"
    find(".c-avatar").click
    click_on "Export collection"

    file = downloaded(name)
    expect(ExportFormatRules.problems(file.binread)).to eq([])
    expect(JSON.parse(file.read)["lots"].size).to eq(1)
    expect(page).to have_css("h1", text: "My collection")
  end
end
