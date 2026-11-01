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
    return remove(upload, result(:expired, upload:)) if upload.expired?

    bytes = upload.read
    return remove(upload, result(:unreadable, upload:)) unless bytes

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

        checksum = current.checksum
        next remove(current, result(:unreadable, upload: current)) unless checksum

        plan = import.replan
        next remove(current, result(:nothing_to_change, import:, plan:)) if plan.nothing_to_change?

        now = plan.fingerprint(checksum)
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
        price_paid_cents: cents, location_key: row.identity.last, # the comparison key; resolved to an id once the locations are written
        created_at: Time.iso8601(lot["added_at"]), updated_at: Time.iso8601(lot["changed_at"]) }
    end

    # Delete the removed lots (the lots of a removed location are among them, so the foreign key never fires), write the
    # locations, read them once (at most 500 rows), then upsert the lots with their place and key. One statement per
    # BATCH_SIZE lots, never one per lot (FR-4). The upsert is on the lot's identity, so a changed lot keeps its id (FR-9) and
    # a renamed location's lots stay where they are; the rows were validated by the reader, so the bulk statements skip Lot's
    # callbacks and validations on purpose (spec 028 FR-3, ruled 2026-10-20; AC-2.4 checks the rows against Lot). Then the
    # view (spec 032 research R3).
    def write!(plan, rows)
      plan.removed_lots.map(&:id).each_slice(CollectionImport::BATCH_SIZE) { |ids| @account.lots.where(id: ids).delete_all }
      CollectionImport::LocationChanges.write!(@account, plan.locations)
      place_ids = @account.locations.pluck(:name_key, :id).to_h
      (plan.added_rows + plan.changed_rows).each_slice(CollectionImport::BATCH_SIZE) do |slice|
        upsert_lots!(slice.map { |row| placed(rows.fetch(row.number), place_ids) })
      end
      # Only a written lot makes the lists that point at lots wrong (spec 029 decision 11, AC-9.17).
      CollectionImport::WorkingState.clear!(@account) if plan.writes_lots?
      @account.user.update!(collection_view: plan.view_change) if plan.view_change
    end

    # One multi-row INSERT .. ON CONFLICT per batch, on the lot's identity, setting quantity and both times: what
    # Lot.upsert_all wrote, without its per-value type casting, which took 2.6 of the 4 seconds of a 50,000-lot apply that
    # replaces every lot (spec 032 Phase 8 measurement, maintainer's ruling 2026-10-24). The values go in through ?
    # placeholders, quoted by the connection (sanitize_sql_array), never interpolated; the rows were validated by the reader.
    LOT_WRITE_COLUMNS = %i[account_id catalog_entry_id quantity finish condition price_paid_cents location_id lot_key created_at updated_at].freeze
    LOT_ROW_MARKS = "(#{Array.new(LOT_WRITE_COLUMNS.size, "?").join(", ")})".freeze

    def upsert_lots!(attributes)
      sql = "INSERT INTO lots (#{LOT_WRITE_COLUMNS.join(", ")}) VALUES #{Array.new(attributes.size, LOT_ROW_MARKS).join(", ")} " \
        "ON CONFLICT (account_id, catalog_entry_id, lot_key) DO UPDATE SET quantity = excluded.quantity, created_at = excluded.created_at, updated_at = excluded.updated_at"
      Lot.connection.execute(Lot.sanitize_sql_array([ sql, *attributes.flat_map { |row| row.values_at(*LOT_WRITE_COLUMNS) } ]))
    end

    # One pass over the built attributes: the location's id and the key that carries it.
    def placed(attributes, place_ids)
      location_id = place_ids.fetch(attributes[:location_key]) if attributes[:location_key]
      attributes.except(:location_key).merge(location_id:,
        lot_key: Lot.key_for(attributes[:finish], attributes[:condition], attributes[:price_paid_cents], location_id))
    end
end
