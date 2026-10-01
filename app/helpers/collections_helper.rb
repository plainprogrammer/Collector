module CollectionsHelper
  # A collection URL with its params in one form (spec 006): bulk mode or the view, the filter, the
  # table's sort and the page (left out on page 1).
  def collection_listing_path(query: nil, sort: nil, page: nil, bulk: nil, view: nil)
    collection_path({ bulk:, view:, q: query.presence, page: (page.to_i if page.to_i > 1) }.merge(sort&.to_params || {}).compact)
  end

  # A sortable column header (spec 006 AC-3.2): it states the order and leads to the next one. Outside
  # bulk mode it's a link; in bulk mode a button of the bulk form, so the ticks go along (FR-4).
  def sort_header(table, column, label, bulk: false, **html)
    url = collection_listing_path(query: table.query, sort: table.sort.toward(column), **(bulk ? { bulk: 1 } : { view: "table" }))
    control = bulk ? button_tag(label, type: "submit", name: "go", value: url, class: "c-table__sort") : link_to(label, url, class: "c-table__sort")
    tag.th(control, "aria-sort": table.sort.aria_sort(column), **html)
  end

  def items_count(count) = pluralize(number_with_delimiter(count), "item")

  # The bulk bar's count (spec 006 AC-5.1–5.5): selected copies against the filter's copies.
  def selection_count(state, matching)
    if state.everything? && matching.positive?
      safe_join([ "All ", tag.span(number_with_delimiter(matching)), " #{"item".pluralize(matching)} selected" ])
    else
      safe_join([ tag.span(number_with_delimiter(state.copies)), " of #{number_with_delimiter(matching)} selected" ])
    end
  end

  # Why a change was refused at the lot cap (spec 006 AC-6.4, AC-7.5).
  def over_cap_message(prefix, lot)
    "#{prefix} #{lot.entry.name} (#{set_number(lot.entry)}) would have more than #{number_with_delimiter(Lot::MAX_QUANTITY)} copies in one lot."
  end
end
