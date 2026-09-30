class LotsController < ApplicationController
  before_action :set_entry, only: %i[new create]
  before_action :set_lot, only: %i[edit update destroy]

  def new
    @form = Lot::Form.new(entry: @entry)
  end

  def create
    @form = Lot::Form.new(**lot_params.to_h.symbolize_keys, entry: @entry)
    return render(:new, status: :unprocessable_content) unless @form.valid?

    Lot.add!(account: Current.account, entry: @entry, **@form.lot_attributes)
    redirect_to catalog_entry_path(@entry, **card_params), status: :see_other,
      notice: "Added #{@form.lot_attributes[:quantity]} × #{@entry.name} (#{helpers.set_number(@entry)}) to your collection."
  rescue ActiveRecord::RecordInvalid => error
    @form.absorb(error.record)
    render :new, status: :unprocessable_content
  end

  def edit
    @form = Lot::Form.from(@lot)
  end

  def update
    @form = Lot::Form.new(**lot_params.to_h.symbolize_keys, entry: @lot.entry)
    return render(:edit, status: :unprocessable_content) unless @form.valid?

    @lot.revise!(@form.lot_attributes)
    redirect_to catalog_entry_path(@lot.entry, **card_params), status: :see_other, notice: "Saved."
  rescue ActiveRecord::RecordInvalid
    @form.absorb(@lot)
    render :edit, status: :unprocessable_content
  end

  def destroy
    @lot.destroy!
    redirect_to catalog_entry_path(@lot.entry, **card_params), status: :see_other,
      notice: "Removed #{@lot.quantity} × #{@lot.entry.name} (#{helpers.set_number(@lot.entry)}) from your collection."
  end

  private
    def set_entry = @entry = Catalog::Entry.includes(:set).find_by!(external_key: params[:entry_external_key])

    def set_lot = @lot = Current.account.lots.includes(entry: :set).find(params[:id])

    def lot_params = params.expect(lot: %i[quantity finish condition price_paid])
end
