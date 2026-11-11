# Moving every copy of the selected lots to one location, or to none, from its own page (spec 041). A bulk action like Set
# condition: the page's ticks were recorded first, and every answer returns to the bulk table it came from.
class Collections::MovesController < ApplicationController
  include BulkSelected

  before_action :set_choices
  before_action :require_choices

  rescue_from(ActiveRecord::InvalidForeignKey) { raise ActiveRecord::RecordNotFound } # the destination was removed meanwhile

  def new
    @copies = @selection.copies
    @to = ""
  end

  def create
    @to = params[:to].to_s
    return refuse(alert: BulkSelection::NONE_LEFT, copies: 0) unless selection?

    @copies = @selection.copies
    return refuse(to_errors: [ Lot::BulkMove::CHOOSE ]) if @to.blank?

    destination = destination_for(@to)
    result = Lot::BulkMove.new(account: Current.account, lots: @selection.lots, to: destination, sort: @selection.sort).apply!
    @selection.after_move!(result.ids)
    redirect_to @bulk_path, status: :see_other, notice: helpers.moved_message(result, destination)
  rescue Lot::CapExceeded => error
    refuse(alert: helpers.over_cap_message("Nothing moved.", error.lot))
  rescue Lot::BulkMove::NothingToMove => error
    refuse(alert: error.message)
  rescue Lot::BulkMove::NoLotsLeft => error # the lots went between the check above and the write lock
    refuse(alert: error.message, copies: 0)
  end

  private
    # nil for "No location"; any other value must be the id of one of the account's places or zones, else 404 (decision 6 (5),
    # AC-2.3; spec 065 AC-3.3). A deck's own row is 404 (spec 062 AC-5.2, spec 065 decision 7): the move writes with update_all,
    # which would put lots in a deck. A `deck:` value is no id, so the ID check answers 404 for it too.
    def destination_for(value)
      return if value == CollectionFilter::Place::NONE
      raise ActiveRecord::RecordNotFound unless value.match?(CollectionFilter::Place::ID)

      Current.account.locations.find_placeable!(value)
    end

    # Every refusal re-renders the move page with 422 and keeps the selection and the chosen To.
    def refuse(alert: nil, to_errors: [], copies: @copies)
      @copies, @to_errors = copies, to_errors
      flash.now[:alert] = alert if alert
      render :new, status: :unprocessable_content
    end

    # The order of answers (decision 6): BulkSelected has answered a GET with nothing selected; an account with no place and
    # no deck has nothing to move to, whatever was submitted. The selection is kept.
    def require_choices
      redirect_to @bulk_path, status: :see_other, alert: Lot::BulkMove::NO_LOCATIONS unless @choices.any?
    end

    # What the To field offers: the prompt, "No location" (left out under the "No location" filter), Places and Decks, the
    # selection's own place or zone left out (spec 065 decision 7; a deck filter leaves out nothing, its value is no id).
    def set_choices
      @choices = Location::Choices.new(Current.account)
      @own = @selection ? @selection.location_filter : ""
      @leading = [ [ "Choose…", "" ] ] + (@own == CollectionFilter::Place::NONE ? [] : [ [ "No location", CollectionFilter::Place::NONE ] ])
    end
end
