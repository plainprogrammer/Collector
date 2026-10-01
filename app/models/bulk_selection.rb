# The lots a collector has ticked in bulk mode (spec 006 FR-4), kept for their session and tied to the
# filter and sort they were ticked under. Normally the marks are the selected lots; once "Select all"
# is ticked, every matching lot is selected and the marks are the exceptions.
class BulkSelection < ApplicationRecord
  NOTHING_SELECTED = "Select at least one item.".freeze
  NONE_LEFT = "None of the selected items are in your collection any more.".freeze

  belongs_to :session
  belongs_to :account
  has_many :marks, class_name: "BulkSelection::Mark", dependent: :delete_all

  def self.for(session) = find_or_create_by!(session:) { |selection| selection.account = session.user.account }

  def sort = CollectionTable::Sort.from_key(sort_key)
  def context?(query, sort) = self.query == query && sort_key == sort.key

  # The selected lots, always within the account and the filter (AC-8.1, AC-8.2).
  def lots
    matching = CollectionFilter.lots(account, query)
    all_matching? ? matching.where.not(id: marks.select(:lot_id)) : matching.where(id: marks.select(:lot_id))
  end

  def copies = lots.sum(:quantity)
  def everything? = all_matching? && marks.none?

  # Empty again, under a filter and sort: Edit many, a changed filter or sort, a removal (FR-4, AC-7.3).
  # The marks are this selection's own rows, so deleting them in SQL skips nothing.
  def restart!(query:, sort:)
    transaction do
      marks.delete_all
      update!(query:, sort_key: sort.key, all_matching: false)
    end
  end

  # Records one page's ticks (FR-4). The header acts only when it changed from how it was rendered:
  # ticked, it selects every matching lot; unticked, it clears. Otherwise the shown rows decide.
  # Shown ids outside the account's matching lots are ignored (AC-8.1).
  def record!(shown_ids:, ticked_ids:, header_rendered:, header_ticked:)
    transaction do
      if header_ticked != header_rendered
        marks.delete_all
        update!(all_matching: header_ticked)
      else
        shown = CollectionFilter.lots(account, query).where(id: shown_ids).pluck(:id)
        marks.where(lot_id: shown).delete_all
        mark!(all_matching? ? shown - ticked_ids : shown & ticked_ids)
      end
    end
  end

  private
    def mark!(lot_ids)
      marks.insert_all(lot_ids.map { |lot_id| { lot_id:, account_id: } }) if lot_ids.any?
    end
end
