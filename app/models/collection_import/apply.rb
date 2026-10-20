# Applies the account's stored upload (spec 028): reads, judges and prepares everything outside any transaction, then
# decides and writes inside one short all-or-nothing transaction. It touches +account+ only. Collectible-agnostic.
class CollectionImport::Apply
  Result = Data.define(:outcome, :import, :plan, :upload, :fingerprint)

  def initialize(account:, fingerprint:, confirmed:)
    @account = account
    @fingerprint = fingerprint.to_s
    @confirmed = confirmed
  end

  # Decision 13's order. The checks before the transaction are an optimisation that gives the same answer; the
  # transaction decides presence, expiry and the fingerprints once more and its answer is the authoritative one (FR-2).
  def call
    upload = ImportUpload.find_by(account_id: @account.id)
    return result(:missing) unless upload
    return result(:expired, upload:) if upload.expired?

    bytes = upload.read
    return result(:unreadable, upload:) unless bytes

    import = CollectionImport.new(account: @account, file: StringIO.new(bytes))
    return refuse(upload, import) unless import.applicable?

    decide(upload, import, rows_to_write(import))
  end

  private
    def decide(upload, import, rows)
      ImportUpload.transaction do
        current = ImportUpload.find_by(account_id: @account.id)
        next result(:missing) unless current&.id == upload.id
        next result(:expired, upload: current) if current.expired?

        plan = import.replan
        next remove(current, result(:nothing_to_change, import:, plan:)) if plan.nothing_to_change?

        now = plan.fingerprint(current.checksum)
        next stale(current, import, plan, now) unless @fingerprint == now && current.fingerprint == now
        next result(:unconfirmed, import:, plan:, upload: current, fingerprint: now) if plan.removes? && !@confirmed

        write!(plan, rows)
        remove(current, result(:applied, import:, plan:))
      end
    end

    # The stored plan changed: keep the upload with the fingerprint of the plan the collector is about to be shown.
    def stale(current, import, plan, now)
      current.update!(fingerprint: now)
      result(:stale, import:, plan:, upload: current, fingerprint: now)
    end

    # The file is destroyed row first; its blob is released after the commit, rescuing every failure (ImportUpload).
    def remove(upload, result)
      upload.remove!
      result
    end

    def refuse(upload, import)
      upload.remove!
      result(:refused, import:, upload:)
    end

    def result(outcome, import: nil, plan: nil, upload: nil, fingerprint: nil) = Result.new(outcome:, import:, plan:, upload:, fingerprint:)

    # Every attribute hash of the upsert, by row number, built before the lock (time parsing, price, lot key).
    def rows_to_write(import)
      import.rows.reject(&:problem?).to_h { |row| [ row.number, lot_attributes(row, import) ] }
    end

    def lot_attributes(row, import)
      lot = row.lot
      finish = lot["finish"].presence
      condition = lot["condition"].presence
      cents = lot["price_paid"]&.delete(".")&.to_i
      { account_id: @account.id, catalog_entry_id: import.entry_id(row), quantity: lot["quantity"], finish:, condition:,
        price_paid_cents: cents, lot_key: Lot.key_for(finish, condition, cents),
        created_at: Time.iso8601(lot["added_at"]), updated_at: Time.iso8601(lot["changed_at"]) }
    end

    # One statement per BATCH_SIZE lots, never one per lot (FR-4). The upsert is on the lot's identity, so a changed
    # lot keeps its id (FR-9); the rows were validated by the reader. The bulk statements skip Lot's callbacks and
    # validations on purpose (spec 028 FR-3, ruled 2026-10-20; AC-2.4 checks the rows against Lot).
    def write!(plan, rows)
      plan.removed_lots.map(&:id).each_slice(CollectionImport::BATCH_SIZE) { |ids| @account.lots.where(id: ids).delete_all }
      (plan.added_rows + plan.changed_rows).each_slice(CollectionImport::BATCH_SIZE) do |slice|
        Lot.upsert_all(slice.map { |row| rows.fetch(row.number) }, unique_by: %i[account_id catalog_entry_id lot_key],
          update_only: %i[quantity created_at updated_at], record_timestamps: false, returning: false)
      end
      CollectionImport::WorkingState.clear!(@account)
      @account.user.update!(collection_view: plan.view_change) if plan.view_change
    end
end
