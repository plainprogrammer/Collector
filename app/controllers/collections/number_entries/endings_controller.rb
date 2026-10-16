# Done (spec 026 decision 5): the list and its lines go, the copies stay, and the collector is back on their collection.
class Collections::NumberEntries::EndingsController < ApplicationController
  def create
    Current.account.number_entry&.destroy!
    redirect_to collection_path, status: :see_other
  end
end
