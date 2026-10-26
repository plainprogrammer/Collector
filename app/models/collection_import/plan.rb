# What applying a file to the collection would do, and the fingerprint that ties an apply to the preview that showed it
# (spec 028 decision 2) and, for a version 2 file, of the locations (spec 029 decision 11). The one place that lists what
# an apply writes.
class CollectionImport::Plan
  attr_reader :added_rows, :changed_rows, :removed_lots, :view_change, :locations

  def initialize(outcomes, view_change, locations)
    @added_rows = outcomes.fetch(:added_rows)
    @changed_rows = outcomes.fetch(:changed_rows)
    @removed_lots = outcomes.fetch(:removed_lots)
    @matched = outcomes.fetch(:matched_lots)
    @view_change = view_change
    @locations = locations
  end

  def held_for(row) = @matched.fetch(row.identity)

  # Nothing to change: no lot, no location and no view change (spec 028 decision 12, spec 029 decision 10).
  def nothing_to_change? = !writes_lots? && view_change.nil? && locations.nothing_to_change?

  # Whether the apply writes a lot; only then does it clear the working state that points at lots (spec 029 AC-9.17).
  def writes_lots? = added_rows.any? || changed_rows.any? || removed_lots.any?

  def removes? = removed_lots.any? || locations.removes?

  def counts = { added: added_rows.size, changed: changed_rows.size, removed: removed_lots.size }

  # A digest of the stored file and of the plan: the added and changed rows and their outcome, every changed and removed
  # lot's id, quantity and times at full precision, and the view change.
  def fingerprint(file_checksum)
    parts = [ file_checksum,
      added_rows.map { |row| [ row.number, "added" ] },
      changed_rows.map { |row| lot_part(held_for(row)).unshift(row.number, "changed") },
      removed_lots.sort_by(&:id).map { |lot| lot_part(lot) },
      view_change ]
    parts << locations.fingerprint_part if locations.counted?
    Digest::SHA256.hexdigest(JSON.generate(parts))
  end

  private
    # A lot's place is part of it, so a lot moved between the preview and the apply makes the preview stale (spec 032 AC-11.7).
    def lot_part(lot) = [ lot.id, lot.quantity, lot.created_exact, lot.updated_exact, lot.identity.last ]
end
