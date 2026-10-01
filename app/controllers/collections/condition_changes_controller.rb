# Setting one condition on every selected lot, from its own page (spec 006 Story 6).
class Collections::ConditionChangesController < ApplicationController
  include BulkSelected

  def new
    @copies = @selection.copies
    @vocabulary = @selection.vocabulary
  end

  def create
    @condition = params[:condition]
    return refuse(BulkSelection::NONE_LEFT, copies: 0) unless selection?

    @copies = @selection.copies
    @vocabulary = @selection.vocabulary
    return refuse("That isn't a known condition.") unless @condition == "" || @vocabulary.conditions.key?(@condition)

    changed = Lot::ConditionChange.new(account: Current.account, lots: @selection.lots, condition: @condition.presence, sort: @selection.sort).apply!
    @selection.include!(changed)
    redirect_to @bulk_path, status: :see_other, notice: changed_message
  rescue Lot::CapExceeded => error
    refuse(helpers.over_cap_message("Nothing changed.", error.lot))
  end

  private
    def changed_message
      items = helpers.items_count(@copies)
      @condition.present? ? "Set the condition of #{items} to #{@vocabulary.conditions.fetch(@condition).first}." : "Cleared the condition of #{items}."
    end

    def refuse(message, copies: @copies)
      @copies = copies
      @vocabulary ||= Catalog.collecting_for(Catalog.collecting.keys.first)
      flash.now[:alert] = message
      render :new, status: :unprocessable_content
    end
end
