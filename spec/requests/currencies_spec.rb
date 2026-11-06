require "rails_helper"

# Spec 038 Stories 1 and 2: the Currency page, its write and tenancy.
RSpec.describe "Currency", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }

  def html = Nokogiri::HTML5(response.body)
  def select = html.at_css("select[name='account[currency]']")
  def selected = select.at_css("option[selected]")&.[]("value")
  def save(currency, **extra) = patch(currency_path, params: { account: { currency: } }.merge(extra))
  def main_text = html.at_css("main").text.squish

  context "when signed in" do
    before { sign_in_as(user) }

    it "lists the 20 codes in order, each with its symbol, the account's own selected, and Save (AC-1.2)", :aggregate_failures do
      get edit_currency_path

      expect(response).to have_http_status(:ok)
      expect(html.at_css("h1").text).to eq("Currency")
      expect(html.css("select").size).to eq(1)
      expect(select.css("option").map { |option| option["value"] }).to eq(Collector::Currency::SYMBOLS.keys)
      expect(select.css("option").map(&:text).values_at(0, 4, 6, 7)).to eq([ "USD — $", "EUR — €", "CHF — CHF", "SEK — kr" ])
      expect(selected).to eq("USD")
      expect(html.at_css("label[for='account_currency']").text).to eq("Currency")
      expect(select["aria-describedby"]).to eq("account_currency-hint")
      expect(html.at_css("form[action='#{currency_path}'] input[type=submit]")["value"]).to eq("Save")
      expect(html.css("form[data-controller], select[data-controller], [data-action]").select { |node| node.ancestors("main").any? }).to be_empty
    end

    it "says changing converts nothing, and how many lots have a price (AC-1.6)", :aggregate_failures do
      sentence = "Changing the currency doesn't convert the prices you've entered. They keep their amounts and are shown in the currency you choose."
      get edit_currency_path
      expect(main_text).to include(sentence)
      expect(main_text).not_to include("price paid.")

      create(:lot, account:, price_paid_cents: 100)
      get edit_currency_path
      expect(main_text).to include("1 lot has a price paid.")

      2.times { create(:lot, account:, price_paid_cents: 250) }
      2.times { create(:lot, account:, price_paid_cents: nil) }
      get edit_currency_path
      expect(main_text).to include(sentence, "3 lots have a price paid.")
    end

    it "saves a code, redirects to More (303) and says so, converting nothing (AC-1.3, AC-1.5)", :aggregate_failures do
      create(:lot, account:, price_paid_cents: 1250)
      before = account.lots.pluck(:id, :price_paid_cents, :lot_key)

      save("EUR")

      expect(response).to have_http_status(:see_other).and redirect_to(more_path)
      follow_redirect!
      expect(html.at_css("#status").text.squish).to eq("Prices are now shown in EUR.")
      expect(account.reload.currency).to eq("EUR")
      expect(account.lots.pluck(:id, :price_paid_cents, :lot_key)).to eq(before)
      get edit_currency_path
      expect(selected).to eq("EUR")
    end

    it "refuses a code outside the 20 with a field error, changing nothing (AC-1.7)", :aggregate_failures do
      account.update!(currency: "GBP")
      [ "XYZ", "eur", "", "EUR " ].each do |code|
        save(code)
        expect(response).to have_http_status(:unprocessable_content), code.inspect
        expect(html.at_css("#account_currency-error").text.squish).to eq("Choose one of the listed currencies."), code.inspect
        expect(html.at_css(".c-field--invalid select")["aria-describedby"]).to eq("account_currency-hint account_currency-error")
        expect(selected).to eq("GBP"), code.inspect
        expect(html.css(".field_with_errors")).to be_empty # Rails' wrapper would break the field's layout
        expect(account.reload.currency).to eq("GBP"), code.inspect
      end
    end

    it "answers 400 to a request without the account parameter (AC-1.7)", :aggregate_failures do
      patch currency_path, params: { currency: "EUR" }
      expect(response).to have_http_status(:bad_request)
      expect(account.reload.currency).to eq("USD")
    end

    it "changes only the signed-in account's currency, whatever else the request names (AC-2.1, AC-2.2)", :aggregate_failures do
      other = create(:user)
      create(:lot, account: other.account, price_paid_cents: 1250)

      save("EUR", id: other.account.id, account_id: other.account.id)
      patch currency_path, params: { account: { currency: "JPY", id: other.account.id, account_id: other.account.id } }

      expect([ account.reload.currency, other.account.reload.currency ]).to eq(%w[JPY USD])
      delete session_path
      sign_in_as(other)
      get collection_path(view: "table")
      expect(html.at_css("table.c-table").text).to include("$12.50")
    end
  end

  context "when signed out" do
    it "sends a visitor to sign in, reading and writing nothing (AC-1.8)", :aggregate_failures do
      account # an instance with a user, so sign-in rather than first-run sign-up
      get edit_currency_path
      expect(response).to redirect_to(new_session_path)
      patch currency_path, params: { account: { currency: "EUR" } }
      expect(response).to redirect_to(new_session_path)
      expect(account.reload.currency).to eq("USD")
    end
  end
end
