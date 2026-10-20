# Number entry (spec 026): choose a set and a language, then add cards by collector number, line after line. A typed
# set redirects to the page's own link for it (type, code and language), so a reload or Back keeps the choice.
class Collections::NumberEntriesController < ApplicationController
  include NumberEntryPage

  def show
    set_choice
    return redirect_to(page_path) if @choice.chosen? && !@choice.canonical?(params)

    render_page
  end
end
