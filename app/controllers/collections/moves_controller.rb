# Moving every copy of the selected lots to one location, or to none, from its own page (spec 041). A bulk action like Set
# condition: the page's ticks were recorded first, and every answer returns to the bulk table it came from.
class Collections::MovesController < ApplicationController
  include BulkSelected

  before_action :require_locations
  before_action :set_destinations

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
    # nil for "No location"; any other value must be one of the account's location ids, else 404 (decision 6 (5), AC-2.3).
    def destination_for(value)
      return if value == CollectionFilter::Place::NONE
      raise ActiveRecord::RecordNotFound unless value.match?(CollectionFilter::Place::ID)

      Current.account.locations.find(value)
    end

    # Every refusal re-renders the move page with 422 and keeps the selection and the chosen To.
    def refuse(alert: nil, to_errors: [], copies: @copies)
      @copies, @to_errors = copies, to_errors
      flash.now[:alert] = alert if alert
      render :new, status: :unprocessable_content
    end

    # The order of answers (decision 6): BulkSelected has answered a GET with nothing selected; an account with no location
    # has nothing to move to, whatever was submitted. The selection is kept.
    def require_locations
      redirect_to @bulk_path, status: :see_other, alert: Lot::BulkMove::NO_LOCATIONS unless Current.account.locations.exists?
    end

    # The To field's options: the prompt (""), "No location" ("none", the location filter's word, spec 037 decision 1), then the
    # account's locations in the locations page's order; the selection's own place is left out (AC-2.1).
    def set_destinations
      own = @selection ? @selection.location_filter : ""
      locations = Current.account.locations.ordered.reject { |location| location.id.to_s == own }
      @destinations = [ [ "Choose…", "" ] ] + (own == CollectionFilter::Place::NONE ? [] : [ [ "No location", CollectionFilter::Place::NONE ] ]) +
        locations.map { |location| [ location.name, location.id ] }
    end
end
