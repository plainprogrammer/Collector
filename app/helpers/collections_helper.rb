module CollectionsHelper
  # A collection URL with its params in one form (spec 006): the view or bulk mode, the filter, the
  # table's sort and the page (left out on page 1).
  def collection_listing_path(query: nil, sort: nil, page: nil, bulk: nil, view: nil)
    collection_path({ bulk:, view:, q: query.presence, page: (page.to_i if page.to_i > 1) }.merge(sort&.to_params || {}).compact)
  end

  # A sortable column header (spec 006 AC-3.2): it states the order, and links to the next one.
  def sort_header(table, column, label, **html)
    url = collection_listing_path(query: table.query, sort: table.sort.toward(column), view: "table")
    tag.th(link_to(label, url, class: "c-table__sort"), "aria-sort": table.sort.aria_sort(column), **html)
  end
end
