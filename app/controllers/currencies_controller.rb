# Spec 038: the signed-in collector's currency. Every lookup goes through Current.account, and nothing in a request names
# an account, so there is no other account to reach (AC-2.2).
class CurrenciesController < ApplicationController
  def edit
    @account = Current.account
    @priced = priced_lots
  end

  def update
    @account = Current.account
    if @account.update(params.expect(account: [ :currency ]))
      redirect_to more_path, notice: "Prices are now shown in #{@account.currency}.", status: :see_other
    else
      @messages = @account.errors.messages_for(:currency)
      @account.restore_attributes # Current.account must not keep the rejected code, and the select shows the saved one
      @account.errors.clear # the page shows @messages; left on the record, Rails would wrap the field in .field_with_errors
      @priced = priced_lots
      render :edit, status: :unprocessable_content
    end
  end

  private
    # One COUNT for the page's second sentence (spec 038 decision 5).
    def priced_lots = @account.lots.where.not(price_paid_cents: nil).count
end
