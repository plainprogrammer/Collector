# What applying a file to the collection would do, and the fingerprint that ties an apply to the preview that showed it
# (spec 028 decision 2). The one place that lists what an apply writes.
class CollectionImport::Plan
  attr_reader :added_rows, :changed_rows, :removed_lots, :view_change

  def initialize(outcomes, view_change)
    @added_rows = outcomes.fetch(:added_rows)
    @changed_rows = outcomes.fetch(:changed_rows)
    @removed_lots = outcomes.fetch(:removed_lots)
    @matched = outcomes.fetch(:matched_lots)
    @view_change = view_change
  end

  def held_for(row) = @matched.fetch(row.identity)

  def nothing_to_change? = added_rows.empty? && changed_rows.empty? && removed_lots.empty? && view_change.nil?

  def removes? = removed_lots.any?

  def counts = { added: added_rows.size, changed: changed_rows.size, removed: removed_lots.size }

  # A digest of the stored file and of the plan: the added and changed rows and their outcome, every changed and removed
  # lot's id, quantity and times at full precision, and the view change.
  def fingerprint(file_checksum)
    parts = [ file_checksum,
      added_rows.map { |row| [ row.number, "added" ] },
      changed_rows.map { |row| lot_part(held_for(row)).unshift(row.number, "changed") },
      removed_lots.sort_by(&:id).map { |lot| lot_part(lot) },
      view_change ]
    Digest::SHA256.hexdigest(JSON.generate(parts))
  end

  private
    def lot_part(lot) = [ lot.id, lot.quantity, lot.created_exact, lot.updated_exact ]
end
