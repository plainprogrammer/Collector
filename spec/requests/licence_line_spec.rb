require "rails_helper"

# Spec 084 Stories 1 and 2: Collector's licence line ends every page's footer, for everyone, worded from the build facts.
RSpec.describe "The licence line", type: :request do
  let(:sha) { "a9f6de7c0ffee1234567890abcdef1234567890a" }
  let(:tail) { " is free software under the AGPL-3.0. Get the source code." }

  def html = Nokogiri::HTML5(response.body)

  def line = html.at_css("body > footer.c-footer > p:last-child")

  def link_pairs = line.css("a").map { |link| [ link.text, link["href"] ] }

  def expect_the_unknown_line(path)
    expect(line.text).to eq("Collector (unknown version)#{tail}"), path
    expect(link_pairs).to eq([ [ "AGPL-3.0", "https://www.gnu.org/licenses/agpl-3.0.html" ],
      [ "source code", "https://github.com/plainprogrammer/Collector" ] ]), path
  end

  it "ends the footer of a collector's pages (AC-1.1, AC-1.4)", :aggregate_failures do
    lot = create(:lot, account: sign_in_as(create(:user)).account)
    [ collection_path, catalog_entry_path(lot.entry), scanner_path, more_path ].each do |path|
      get path
      expect_the_unknown_line(path)
      expect(line.css("a").map { |link| link.attributes.keys }).to all(match_array(%w[rel href])), path
    end
  end

  it "ends the deck page and an admin page (AC-1.1)", :aggregate_failures do
    admin = sign_in_as(create(:admin))
    deck = create(:deck, account: admin.account)

    [ deck_path(deck), admin_catalog_path ].each do |path|
      get path
      expect_the_unknown_line(path)
    end
  end

  it "is on a visitor's sign-in and sign-up pages (AC-1.2)", :aggregate_failures do
    get new_registration_path
    expect_the_unknown_line("first-run sign-up")

    create(:user)
    InstanceSetting.current.update!(sign_up_open: true)
    [ new_session_path, new_registration_path ].each do |path|
      get path
      expect_the_unknown_line(path)
    end
  end

  it "is on the open catalog's pages for a visitor (AC-1.3)", :aggregate_failures, :public_catalog do
    create(:user)
    entry = create(:mtg_printing).entry

    [ catalog_entries_path, catalog_entry_path(entry) ].each do |path|
      get path
      expect(response).to have_http_status(:ok), path
      expect_the_unknown_line(path)
    end
  end

  it "reads a release's facts and links the given address, signed out and in (AC-2.1)", :aggregate_failures do
    build_facts(version: "0.3.0", revision: sha, source_url: "https://example.test/tree/#{sha}")

    create(:user)
    get new_session_path
    expect(line.text).to eq("Collector 0.3.0 (a9f6de7)#{tail}")
    expect(link_pairs.last).to eq([ "source code", "https://example.test/tree/#{sha}" ])

    sign_in_as(create(:user))
    get collection_path
    expect(line.text).to eq("Collector 0.3.0 (a9f6de7)#{tail}")
    expect(link_pairs.last).to eq([ "source code", "https://example.test/tree/#{sha}" ])
  end

  it "reads the edge version (AC-2.2)" do
    build_facts(version: "edge", revision: sha)
    create(:user)
    get new_session_path

    expect(line.text).to start_with("Collector edge (a9f6de7) is free software")
  end

  it "shows no parentheses when there is a version and no revision (AC-2.3)" do
    build_facts(version: "0.3.0")
    create(:user)
    get new_session_path

    expect(line.text).to eq("Collector 0.3.0#{tail}")
  end

  it "reads as no version for one that breaks the rule (AC-2.7)" do
    build_facts(version: "0.3 .0")
    create(:user)
    get new_session_path

    expect(line.text).to eq("Collector (unknown version)#{tail}")
  end

  it "shows no SHA for a revision that isn't 40 characters (AC-2.8)" do
    build_facts(version: "0.3.0", revision: sha.first(7))
    create(:user)
    get new_session_path

    expect(line.text).to eq("Collector 0.3.0#{tail}")
  end

  it "links upstream, and renders no script address, for an unsafe source address (AC-2.9)", :aggregate_failures do
    build_facts(version: "0.3.0", source_url: "javascript:alert(1)")
    create(:user)
    get new_session_path

    expect(link_pairs.last).to eq([ "source code", "https://github.com/plainprogrammer/Collector" ])
    expect(response.body).not_to include("javascript:")
  end

  it "shows a version without its surrounding whitespace (AC-2.11)" do
    build_facts(version: " 0.3.0\n", revision: "#{sha}\n")
    create(:user)
    get new_session_path

    expect(line.text).to eq("Collector 0.3.0 (a9f6de7)#{tail}")
  end

  it "shows the short SHA in lower case (AC-2.12)" do
    build_facts(version: "0.3.0", revision: sha.upcase)
    create(:user)
    get new_session_path

    expect(line.text).to eq("Collector 0.3.0 (a9f6de7)#{tail}")
  end

  it "keeps exactly its two links when the version names a link's words (AC-2.13)", :aggregate_failures do
    build_facts(version: "AGPL-3.0", revision: sha)
    create(:user)
    get new_session_path

    expect(line.css("a").size).to eq(2)
    expect(link_pairs.map(&:first)).to eq([ "AGPL-3.0", "source code" ])
  end

  it "names the SHA alone when the version is refused (AC-2.14)" do
    build_facts(version: "bad version", revision: sha)
    create(:user)
    get new_session_path

    expect(line.text).to eq("Collector (unknown version, a9f6de7)#{tail}")
  end

  it "appears once on the sign-in form shown again with 422 and with 429 (AC-1.6)", :aggregate_failures do
    user = create(:user)
    attempt = -> { post session_path, params: { email_address: user.email_address, password: "wrong" } }

    10.times { attempt.call }
    expect(response).to have_http_status(:unprocessable_content)
    expect(html.css("p").select { |p| p.text.end_with?("Get the source code.") }.size).to eq(1)

    attempt.call
    expect(response).to have_http_status(:too_many_requests)
    expect(html.css("p").select { |p| p.text.end_with?("Get the source code.") }.size).to eq(1)
  end

  it "reads the facts with no query (AC-2.10)" do
    expect(count_queries { Collector::BuildFacts.current.licence_parts }).to eq(0)
  end
end
