require "rails_helper"

RSpec.describe "Edit many", type: :request do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  def own(name = "Lightning Bolt", **options) = owned_printing(name, account: user.account, **options)
  def page_html = Nokogiri::HTML5(response.body)

  it "offers Edit many in the filter bar and its narrow menu, from the grid and the table", :aggregate_failures do
    own
    [ collection_path, collection_path(view: "table") ].each do |path|
      get path
      expect(page_html.css(".c-filterbar button[form=edit-many]").map { |button| [ button.text, button["class"] ] }).to eq([
        [ "Edit many", "c-btn c-btn--secondary c-btn--sm c-filterbar__bulk" ], [ "Edit many", "c-menu__item" ]
      ])
      form = page_html.at_css("form#edit-many")
      expect([ form["method"], form["action"], form["data-turbo-frame"], form.key?("hidden") ]).to eq([ "post", collection_selection_path, nil, true ])
    end
  end

  it "carries the filter and sort into Edit many", :aggregate_failures do
    own
    get collection_path(view: "table", q: "bolt", sort: "price", dir: "desc")
    fields = page_html.css("form#edit-many input[type=hidden]").to_h { |input| [ input["name"], input["value"] ] }
    expect(fields.except("authenticity_token")).to eq("q" => "bolt", "sort" => "price", "dir" => "desc")
  end
end
