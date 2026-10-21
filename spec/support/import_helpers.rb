# Builders for export files in the specs of spec 025 and spec 028.
module ImportHelpers
  # A stand-in plan for specs that store an upload before CollectionImport#plan is under test.
  FakePlan = Data.define(:value) { def fingerprint(_checksum) = value }

  def import_printing(**entry) = create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, **entry)).entry

  def import_row(entry, quantity: 1, finish: nil, condition: nil, price_paid: nil, added_at: "2026-10-01T10:00:00Z", changed_at: added_at)
    { "entry" => { "collectible_type" => entry.collectible_type, "source_id" => entry.external_key, "name" => entry.name,
                   "set_code" => entry.set.code, "collector_number" => entry.number, "language" => entry.language },
      "quantity" => quantity, "finish" => finish, "condition" => condition, "price_paid" => price_paid,
      "added_at" => added_at, "changed_at" => changed_at }
  end

  def import_file(user, lots, **fields)
    { "format" => "collector-export", "format_version" => 1, "exported_at" => "2026-10-15T09:00:00Z",
      "profile" => { "name" => user.name, "email_address" => user.email_address, "collection_view" => user.collection_view },
      "currency" => "USD", "lots" => lots }.merge(fields.stringify_keys)
  end

  def import_io(data) = StringIO.new(data.is_a?(String) ? data : JSON.generate(data))

  def import_upload_file(data, type: "application/json", name: "export.json")
    Rack::Test::UploadedFile.new(import_io(data), type, original_filename: name)
  end

  # A held lot with the file's times, as the model specs of spec 025 make them.
  def held_lot(account, entry, quantity:, added_at: "2026-10-01T10:00:00Z", changed_at: added_at, **attributes)
    create(:lot, account:, entry:, quantity:, created_at: Time.iso8601(added_at), updated_at: Time.iso8601(changed_at), **attributes)
  end

  # Previews +data+ for +account+ and stores it, as the preview page does; returns the ImportUpload. A file the preview
  # would not store (refused, problem rows, nothing to change) raises, so a spec cannot pass on a state the page never
  # reaches; +forced+ stores it anyway, for a spec that needs a stale upload.
  def store_import!(account:, data:, forced: false)
    bytes = data.is_a?(String) ? data : JSON.generate(data)
    import = CollectionImport.new(account:, file: StringIO.new(bytes))
    raise ArgumentError, "the preview would not store this file" unless forced || (import.applicable? && !import.plan.nothing_to_change?)

    ImportUpload.store!(account:, bytes:, plan: import.plan)
  end
end

RSpec.configure do |config|
  %i[model request system].each { |type| config.include ImportHelpers, type: }
end
