# Applies the account's stored upload (spec 028): reads, judges and prepares everything outside any transaction, then
# decides and writes inside one short all-or-nothing transaction. It touches +account+ only: its lots, locations, decks, proxies,
# view and currency (spec 038, spec 062, spec 068). Collectible-agnostic.
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

    decide(upload, import, rows_to_write(import), proxy_attributes(import))
  end

  private
    def decide(upload, import, rows, proxies)
      ImportUpload.transaction do
        current = ImportUpload.find_by(account_id: @account.id)
        next result(:missing) unless current&.id == upload.id
        next result(:expired, upload: current) if current.expired?

        checksum = current.checksum
        next remove(current, result(:unreadable, upload: current)) unless checksum

        plan = import.replan
        # A version 1 to 3 file is judged against the collector's decks again, on what the transaction holds (spec 062 AC-7.4d):
        # before the other checks, so a refusal is never shown as a stale preview offered again.
        next refuse(current, import) if import.refused?
        next remove(current, result(:nothing_to_change, import:, plan:)) if plan.nothing_to_change?

        now = plan.fingerprint(checksum)
        next stale(current, import, plan, now) unless @fingerprint == now && current.fingerprint == now
        next result(:unconfirmed, import:, plan:, upload: current, fingerprint: now) if plan.removes? && !@confirmed

        write!(plan, rows, proxies)
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

    # Every proxy row to write, by row number, built before the lock: the deck's comparison key and the zone's key (resolved to
    # the zone's id once the decks and zones are written), the entry's id, the finish and the quantity. Empty for a file older
    # than version 4 (spec 068 AC-7.8).
    def proxy_attributes(import)
      return {} unless import.proxies_counted?

      import.proxy_rows.reject(&:problem?).to_h do |row|
        deck_key, zone_key, _type, _source_id, finish = row.identity
        [ row.number, { deck_key:, zone_key:, catalog_entry_id: import.proxy_entry_id(row), finish:, quantity: row.quantity } ]
      end
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

    # Delete the removed lots and proxies (those of a removed place, deck or zone are among them, so the foreign key never
    # fires), write the places, decks and zones in `DeckChanges`' order (every removal before any addition), read the places and
    # the zones once (at most 500 places and decks, a few zones each), then upsert the lots with their place and key and the
    # proxies with their zone. One statement per BATCH_SIZE lots or proxies, never one per row (FR-4). The upsert is on the lot's identity, so a changed lot keeps its id (FR-9)
    # and a renamed location's lots stay where they are; the rows were validated by the reader, so the bulk statements skip
    # Lot's callbacks and validations on purpose (spec 028 FR-3, ruled 2026-10-20; AC-2.4 checks the rows against Lot). Then
    # the view (spec 032 research R3). The currency goes first, so any later statement's failure rolls it back with the lots
    # (spec 038 decision 7, AC-6.9). A proxy-only change clears no working state: only a lot makes those lists wrong (spec 068
    # AC-7.11).
    def write!(plan, rows, proxies)
      @account.update!(currency: plan.currency_change.to) if plan.currency_change
      plan.removed_lots.map(&:id).each_slice(CollectionImport::BATCH_SIZE) { |ids| @account.lots.where(id: ids).delete_all }
      plan.proxies.removed.map(&:id).each_slice(CollectionImport::BATCH_SIZE) { |ids| @account.deck_proxies.where(id: ids).delete_all } # Safe: scoped to the account, bound ids; before the zones and decks they sit in
      CollectionImport::DeckChanges.write!(@account, plan.locations, plan.decks)
      places, zones = place_ids, zone_ids
      (plan.added_rows + plan.changed_rows).each_slice(CollectionImport::BATCH_SIZE) do |slice|
        upsert_lots!(slice.map { |row| placed(rows.fetch(row.number), places, zones) })
      end
      (plan.proxies.added + plan.proxies.changed).each_slice(CollectionImport::BATCH_SIZE) do |slice|
        upsert_proxies!(slice.map { |row| proxies.fetch(row.number) }, zones)
      end
      # Only a written lot makes the lists that point at lots wrong (spec 029 decision 11, AC-9.17).
      CollectionImport::WorkingState.clear!(@account) if plan.writes_lots?
      @account.user.update!(collection_view: plan.view_change) if plan.view_change
    end

    # The account's places by comparison key: a zone's key is never among them (spec 062 AC-8.4).
    def place_ids = @account.locations.places.pluck(:name_key, :id).to_h

    # The account's zones by `[deck key, zone key]`, the pair a lot's identity holds, so a zone is never mistaken for a place
    # or for another deck's zone of the same key.
    def zone_ids
      @account.locations.zones_of_decks.joins("JOIN locations parents ON parents.id = locations.parent_id")
        .pluck("parents.name_key", "locations.zone", "locations.id").to_h { |deck_key, zone, id| [ [ deck_key, zone ], id ] }
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

    PROXY_WRITE_COLUMNS = %i[account_id location_id catalog_entry_id finish quantity created_at updated_at].freeze
    PROXY_ROW_MARKS = "(#{Array.new(PROXY_WRITE_COLUMNS.size, "?").join(", ")})".freeze

    # One multi-row INSERT .. ON CONFLICT per batch on the proxy's identity, setting the quantity, so a changed proxy keeps its
    # id and its `created_at`: what `Deck::Proxy.upsert_all` would write, through placeholders like the lots' (the rows were
    # validated by the reader, so the model's validations are skipped on purpose, spec 028 FR-3; a spec checks the written rows
    # against `Deck::Proxy`). The conflict target is the unique index's expression, which also holds for a NULL finish.
    def upsert_proxies!(attributes, zones)
      now = Time.current
      rows = attributes.map do |row|
        [ @account.id, zones.fetch([ row[:deck_key], row[:zone_key] ]), row[:catalog_entry_id], row[:finish], row[:quantity], now, now ]
      end
      sql = "INSERT INTO deck_proxies (#{PROXY_WRITE_COLUMNS.join(", ")}) VALUES #{Array.new(rows.size, PROXY_ROW_MARKS).join(", ")} " \
        "ON CONFLICT (location_id, catalog_entry_id, COALESCE(finish, '')) DO UPDATE SET quantity = excluded.quantity, updated_at = excluded.updated_at"
      Deck::Proxy.connection.execute(Deck::Proxy.sanitize_sql_array([ sql, *rows.flatten ]))
    end

    # One pass over the built attributes: the place's or zone's id and the key that carries it (`Location::Placement`).
    def placed(attributes, places, zones)
      location_id = Location::Placement.resolve(attributes[:location_key], places:, zones:)
      attributes.except(:location_key).merge(location_id:,
        lot_key: Lot.key_for(attributes[:finish], attributes[:condition], attributes[:price_paid_cents], location_id))
    end
end
