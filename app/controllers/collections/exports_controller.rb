# The collector's whole collection as one file in the export format (spec 022), built and sent in the request:
# nothing is stored and no job runs (decision 1).
class Collections::ExportsController < ApplicationController
  def show
    export = CollectionExport.new(account: Current.account, at: Time.current)
    no_store
    send_data export.to_json, type: :json, disposition: :attachment, filename: export.filename
  end

  private
    # Signing in from here lands on the collection, not on this file: Turbo submits the sign-in form and can't
    # follow a redirect to an attachment (decision 9).
    def request_authentication = redirect_to(new_session_path)
end
