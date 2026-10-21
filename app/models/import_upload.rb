# The account's previewed export file, kept briefly so that it can be applied (spec 028 decisions 1, 9; ADR 0022).
class ImportUpload < ApplicationRecord
  EXPIRES_IN = 1.hour
  ORPHAN_GRACE = 10.minutes
  MARKER = "import_upload".freeze

  belongs_to :account
  # No dependent purge: the one removal path below releases the blob after the commit, rescuing every failure.
  has_one_attached :file, dependent: false

  scope :expired, -> { where(expires_at: ..Time.current) }

  before_destroy :remember_blob, prepend: true
  after_destroy_commit :release_blob

  # Keeps +bytes+, replacing the account's earlier upload (decision 1). The blob is made first, outside any transaction
  # (file I/O), already identified and analyzed so Active Storage queues no job (decision 8); a failure after it releases it.
  def self.store!(account:, bytes:, plan:)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes),
      filename: "import-#{account.id}-#{Time.current.utc.strftime("%Y%m%dT%H%M%SZ")}.json",
      content_type: "application/json", identify: false,
      metadata: { "identified" => true, "analyzed" => true, MARKER => true })
    transaction do
      find_by(account_id: account.id)&.remove!
      create!(account:, fingerprint: plan.fingerprint(blob.checksum), expires_at: EXPIRES_IN.from_now, file: blob)
    end
  rescue StandardError
    release(blob) if blob
    raise
  end

  # Deletes the file first, then the blob row, so that a failure leaves a marked, unattached blob for the sweep (the
  # order Blob#purge does not have). Never raises: a removal that fails must not fail the request (decision 9).
  def self.release(blob)
    blob.delete
    blob.destroy
  rescue StandardError => error
    Rails.logger.error("An import upload's blob was not released: #{error.class}")
  end

  # Removes every expired upload, and every marked blob that no attachment holds and that is older than the grace
  # (a preview that crashed between its blob and its record, or a release that failed). Cross-tenant by nature: it runs
  # for the instance. It never lists or deletes paths on disk, and goes on past an item that fails (decision 9).
  def self.sweep!
    expired.find_each { |upload| sweeping { upload.remove! } }
    ActiveStorage::Blob.where.missing(:attachments).where(created_at: ..ORPHAN_GRACE.ago)
      .where("json_extract(active_storage_blobs.metadata, '$.import_upload') = 1").find_each { |blob| release(blob) }
  end

  def self.sweeping
    yield
  rescue StandardError => error
    Rails.logger.error("An import upload was not swept: #{error.class}")
  end

  # The one removal path (store! replacing, the sweep, applying, refusing); an account's deletion reaches the same
  # callbacks through dependent: :destroy.
  def remove! = destroy!

  def expired? = expires_at <= Time.current

  # nil when nothing is attached (a row left without its file): the apply treats that as an unreadable file.
  def checksum = (file.blob.checksum if file.attached?)

  # The stored file's bytes, or nil when it can't be read (removed by the sweep, a newer preview or a fault).
  def read
    file.download
  rescue ActiveStorage::FileNotFoundError
    nil
  end

  private
    def remember_blob = @blob_to_release = (file.blob if file.attached?)

    def release_blob = (self.class.release(@blob_to_release) if @blob_to_release)
end
