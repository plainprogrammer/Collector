# Active Storage's routes are public by default. They are gated app-wide (spec 028 decision 8, ADR 0022):
# - direct-upload creation and the disk service's upload PUT answer 404 until a feature needs them (that feature defines
#   its owner rule, quota and clean-up);
# - every other action needs a sign-in;
# - every action that reads a blob needs an original blob that a record of the signed-in account holds. Variant records and
#   preview images are not authorised yet: the first image feature extends ownership to them (ADR 0022).
module ActiveStorageGate
  extend ActiveSupport::Concern

  included do
    before_action :refuse_uploads, prepend: true
    include Authentication
    before_action :require_blob_owner

    # Active Storage's controllers don't see the application's route helpers directly.
    def request_authentication = redirect_to(main_app.new_session_path)
    private :request_authentication
  end

  private
    def refuse_uploads
      head :not_found if (controller_name == "direct_uploads" && action_name == "create") || (controller_name == "disk" && action_name == "update")
    end

    def require_blob_owner
      blob = gated_blob
      head :not_found unless blob && Current.account && owned_by_account?(blob)
    end

    def gated_blob
      if params[:encoded_key]
        key = ActiveStorage.verifier.verified(params[:encoded_key], purpose: :blob_key)&.with_indifferent_access&.dig(:key)
        ActiveStorage::Blob.find_by(key:) if key
      else
        ActiveStorage::Blob.find_signed(params[:signed_id] || params[:signed_blob_id])
      end
    end

    # A record that answers account_id and holds the blob. A record without one is served to no one.
    def owned_by_account?(blob)
      blob.attachments.includes(:record).any? { |attachment| attachment.record.respond_to?(:account_id) && attachment.record.account_id == Current.account.id }
    end
end
