# How a bulk-mode page shows the session's selection (spec 006 Story 5): which rows are ticked, the
# header and the count. A selection made under another filter or sort shows as nothing (FR-4).
class CollectionTable::SelectionState
  def initialize(table:, selection:)
    @table = table
    @selection = selection if selection&.context?(table.query, table.sort)
  end

  def all? = @selection&.all_matching? || false
  def everything? = @selection&.everything? || false
  def copies = @selection ? @selection.copies : 0
  def selected?(lot) = selected_ids.include?(lot.id)

  # Selected copies not on this page: the live count adds this page's ticks to it (AC-5.8).
  def copies_off_page = @selection ? @selection.lots.where.not(id: lot_ids).sum(:quantity) : 0

  private
    def lot_ids = @table.lots.map(&:id)
    def selected_ids = @selected_ids ||= @selection ? @selection.lots.where(id: lot_ids).pluck(:id).to_set : Set.new
end
