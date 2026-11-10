# The lots a collector has ticked in bulk mode (spec 006 FR-4), kept for their session and tied to the
# filter, location and sort they were ticked under. Normally the marks are the selected lots; once "Select all"
# is ticked, every matching lot is selected and the marks are the exceptions.
class BulkSelection < ApplicationRecord
  NOTHING_SELECTED = "Select at least one item.".freeze
  NONE_LEFT = "None of the selected items are in your collection any more.".freeze

  belongs_to :session
  belongs_to :account
  has_many :marks, class_name: "BulkSelection::Mark", dependent: :delete_all

  def self.for(session) = find_or_create_by!(session:) { |selection| selection.account = session.user.account }

  def sort = CollectionTable::Sort.from_key(sort_key)
  # The location is compared as its stored canonical string, never re-resolved (spec 037 decisions 5 and 7).
  def context?(query, sort, location: "") = self.query == query && sort_key == sort.key && location_filter == location

  # The selected lots, always within the account, the filter and the place (AC-8.1, AC-8.2). A removed or foreign location
  # matches no lot, so nothing is selected (spec 037 decision 7).
  def lots
    matching = CollectionFilter.lots(account, query, location_filter)
    all_matching? ? matching.where.not(id: marks.select(:lot_id)) : matching.where(id: marks.select(:lot_id))
  end

  def copies = lots.sum(:quantity)
  def everything? = all_matching? && marks.none?

  # Selects lots that hold changed copies after Set condition, e.g. a merged lot (AC-6.5).
  def include!(lot_ids)
    all_matching? ? marks.where(lot_id: lot_ids).delete_all : mark!(lot_ids - marks.pluck(:lot_id))
  end

  # The selected lots' collectible vocabulary; a selection spans one collectible (spec 006 Non-Goals).
  def vocabulary = Catalog.collecting_for(lots.pick(Catalog::Entry.arel_table[:collectible_type]) || Catalog.collecting.keys.first)

  # Starts again under a filter, location and sort: Edit many, a changed filter or sort, a removal (FR-4, AC-7.3; spec 037
  # decision 5), and a location's shortcut from its refusal page (spec 059 decision 3). Nothing is selected unless `all:`;
  # then every matching lot is, with no exceptions, set in the same transaction so a failure can't leave the filter stored
  # with nothing ticked. The marks are this selection's own rows, so deleting them in SQL skips nothing.
  #
  # @param query [String] the name filter, already normalised
  # @param sort [CollectionTable::Sort] the table's order
  # @param location [String] the location filter's canonical string (`""`, `"none"` or an id)
  # @param all [Boolean] select every matching lot (the header's state) instead of none
  # @return [true] the result of the update
  def restart!(query:, sort:, location: "", all: false)
    transaction do
      marks.delete_all
      update!(query:, sort_key: sort.key, location_filter: location, all_matching: all)
    end
  end

  # After a move (spec 041 decision 6): under all locations the moved lots still match, so the lots now holding the moved
  # copies are selected (a merged survivor, an excepted destination lot too, as after Set condition, AC-3.9); under a
  # location or "No location" they no longer match, so the selection restarts empty under the same filters and sort, as
  # after Remove (AC-3.13; spec 037 AC-5.6).
  def after_move!(lot_ids)
    return include!(lot_ids) if location_filter.empty?

    restart!(query: query, sort: sort, location: location_filter)
  end

  # Records one page's ticks (FR-4, spec v5.0.0). A header toggle (submitted unlike it was rendered, or
  # reported by scripting) resets the selection to every matching lot or nothing; then only the shown rows
  # whose tick differs from their rendered baseline apply. Without a toggle, the shown rows decide.
  # Shown ids outside the account's matching lots are ignored (AC-8.1).
  def record!(shown_ids:, ticked_ids:, header_rendered:, header_ticked:, baseline_ids: [], header_toggled: false)
    shown = CollectionFilter.lots(account, query, location_filter).where(id: shown_ids).pluck(:id)
    transaction do
      if header_toggled || header_ticked != header_rendered
        marks.delete_all
        update!(all_matching: header_ticked)
        changed = shown.select { |id| ticked_ids.include?(id) != baseline_ids.include?(id) }
        mark!(all_matching? ? changed - ticked_ids : changed & ticked_ids)
      else
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
