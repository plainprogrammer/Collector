# Adds one line of number entry: its copies merge into the collector's lots and the line joins the list (spec 026
# Story 2). A rejected line, or one that needs a choice between matches, comes back as typed and nothing changes (Story 4).
class Collections::NumberEntries::LinesController < ApplicationController
  include NumberEntryPage

  def create
    set_choice
    return redirect_to(page_path, status: :see_other) unless @choice.chosen?

    @line = NumberEntry::LineForm.new(**line_params, set: @choice.set, language: @choice.language)
    return render_page(status: :unprocessable_content) if @line.blank_number? || @line.choice? || @line.invalid?

    added = NumberEntry.add!(account: Current.account, **@line.add_attributes)
    redirect_to page_path(finish: @line.finish), status: :see_other,
      notice: "Added #{added.line.quantity} × #{helpers.number_entry_copy(added.line)} to your collection."
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = Lot::FULL_MESSAGE
    render_page(status: :unprocessable_content)
  end

  private
    def line_params = params.expect(line: %i[number quantity finish line_key pick]).to_h.symbolize_keys
end
