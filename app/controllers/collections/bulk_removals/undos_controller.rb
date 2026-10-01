# Undo of a bulk removal, from the status message right after it (spec 006 AC-7.4–7.7). Only the
# session that removed can undo, so any other removal is not found (AC-8.3).
class Collections::BulkRemovals::UndosController < ApplicationController
  include CollectionListing

  def create
    removal = Current.session.bulk_removals.find(params[:bulk_removal_id])
    removal.undo!(sort: return_sort)
    redirect_to return_path, status: :see_other, notice: "Restored #{helpers.items_count(removal.copies)} to your collection."
  rescue BulkRemoval::NotUndoable
    refuse(BulkRemoval::NO_LONGER_UNDOABLE)
  rescue Lot::CapExceeded => error
    refuse(helpers.over_cap_message("Nothing restored.", error.lot))
  end

  private
    # The collection page the message was on; anything else lands on the collection (AC-7.4).
    def return_path
      @return_path ||= begin
        uri = URI.parse(url_from(params[:return_to]).to_s)
        [ uri.path, uri.query ].compact.join("?") if uri.path == collection_path
      rescue URI::InvalidURIError
        nil
      end || collection_path
    end

    def return_sort
      values = Rack::Utils.parse_query(URI.parse(return_path).query)
      CollectionTable::Sort.parse(values["sort"], values["dir"])
    end

    def refuse(message)
      prepare_collection_at(return_path)
      render_collection_refusal(message)
    end
end
