require "rails_helper"

# Spec 090 Story 4, decision 9 (i): no page says "household", and no request of these pages reads a household or a membership.
RSpec.describe "A household is invisible (spec 090 Story 4)", type: :request do
  let!(:admin) { create(:admin, name: "Ann") }
  let(:paths) { [ collection_path, collection_path(view: "table"), admin_users_path, more_path, catalog_entries_path ] }

  def statements_naming(pattern, &)
    seen = []
    ActiveSupport::Notifications.subscribed(->(*, payload) { seen << payload[:sql] if payload[:sql].match?(pattern) }, "sql.active_record", &)
    seen
  end

  it "shows no page of a collector or an admin the word, and runs no query naming the new tables (AC-4.1, AC-4.5)", :aggregate_failures do
    sign_in_as(admin)
    seen = statements_naming(/\b(households|memberships)\b/i) do
      paths.each do |path|
        get path
        expect(response).to have_http_status(:ok), "#{path} answered #{response.status}"
        expect(response.body.downcase).not_to include("household"), "#{path} says household"
      end
    end
    expect(seen).to be_empty
  end

  it "shows a collector who is not an admin no page with the word (AC-4.1)", :aggregate_failures do
    sign_in_as(create(:user))
    seen = statements_naming(/\b(households|memberships)\b/i) do
      [ collection_path, collection_path(view: "table"), more_path, catalog_entries_path ].each do |path|
        get path
        expect(response.body.downcase).not_to include("household"), "#{path} says household"
      end
    end
    expect(seen).to be_empty
  end

  it "shows no signed-out page the word (AC-4.1)", :aggregate_failures do
    seen = statements_naming(/\b(households|memberships)\b/i) do
      [ new_session_path, new_registration_path ].each do |path|
        get path
        expect(response.body.downcase).not_to include("household"), "#{path} says household"
      end
    end
    expect(seen).to be_empty
  end

  it "lists users as before: a row, its copies and the same buttons (AC-4.5)", :aggregate_failures do
    sign_in_as(admin)
    bo = create(:user, name: "Bo")
    create(:lot, account: bo.account, quantity: 3)
    get admin_users_path
    expect(response.body).to include("Bo", '<td class="is-num">3</td>')
    expect(response.body.downcase).not_to include("household")
  end
end
