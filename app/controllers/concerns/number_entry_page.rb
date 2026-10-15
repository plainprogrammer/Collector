# Number entry's page as each of its actions shows it (spec 026): the chosen set and language, the line form with a
# fresh line key, and the account's list, newest first.
module NumberEntryPage
  extend ActiveSupport::Concern

  private
    def set_choice
      @choice ||= NumberEntry::SetChoice.new(text: params[:set], type: params[:type], language: params[:language])
    end

    def render_page(status: :ok)
      set_choice
      @line ||= NumberEntry::LineForm.new(set: @choice.set, language: @choice.language, finish: params[:finish]) if @choice.chosen?
      @line_key = NumberEntry.new_line_key
      list = Current.account.number_entry
      @lines = list ? list.kept_lines.to_a : []
      @unloaded_catalogs = Catalog.unloaded_titles
      @catalogs_named = Catalog.sources.many?
      render "collections/number_entries/show", status:
    end

    # The page for the chosen set and language, keeping the finish; the bare page when none is chosen.
    def page_path(finish: params[:finish])
      set_choice
      collection_number_entry_path(**(@choice.chosen? ? @choice.to_params : {}), finish: finish.presence)
    end
end
