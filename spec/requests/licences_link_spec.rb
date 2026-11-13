require "rails_helper"

# Spec 087 Story 2: the licence line leads to the page of third-party licences. These examples never request the page
# (its own request spec does); they prove the line's address, its three-link rule and the shared partial.
RSpec.describe "The licence line's link to the third-party licences", type: :request do
  let(:sha) { "a9f6de7c0ffee1234567890abcdef1234567890a" }

  def line = Nokogiri::HTML5(response.body).at_css("body > footer.c-footer > p:last-child")

  def link_pairs = line.css("a").map { |link| [ link.text, link["href"] ] }

  it "uses the address the route has (AC-2.3)" do
    expect(Collector::BuildFacts::LICENCES_PATH).to eq(licences_path)
  end

  it "keeps exactly three links on the fixed words, whatever the version says (AC-2.2)", :aggregate_failures do
    create(:user)

    [ "third-party-licences", "AGPL-3.0", "source-code" ].each do |version|
      build_facts(version: version, revision: sha)
      get new_session_path

      expect(link_pairs.map(&:first)).to eq([ "AGPL-3.0", "source code", "third-party licences" ]), version
      expect(link_pairs.last).to eq([ "third-party licences", "/licences" ]), version
    end
  end

  it "is in the shared notice lines partial, wherever it renders (AC-2.4)" do
    fragment = Nokogiri::HTML5.fragment(ApplicationController.render(partial: "layouts/notice_lines"))

    expect(fragment.css(%(a[href="#{Collector::BuildFacts::LICENCES_PATH}"]))).not_to be_empty
  end
end
