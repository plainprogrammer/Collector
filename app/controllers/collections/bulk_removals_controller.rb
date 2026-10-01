# Removing every selected lot at once (spec 006 Story 7): a confirmation page first, then the
# removal, with a one-time Undo in the status message.
class Collections::BulkRemovalsController < ApplicationController
  include BulkSelected

  def new
    @copies = @selection.copies
    @lots_count = @selection.lots.count
  end

  def create
    return refuse(BulkSelection::NONE_LEFT) unless selection?

    removal = BulkRemoval.remove!(@selection)
    redirect_to @bulk_path, status: :see_other, notice: "Removed #{helpers.items_count(removal.copies)} from your collection.",
      flash: { undo: removal.id }
  end

  private
    def refuse(message)
      @copies, @lots_count = 0, 0
      flash.now[:alert] = message
      render :new, status: :unprocessable_content
    end
end
