Catalog::Pagination = Data.define(:total_count, :page, :per_page) do
  # Non-numeric or non-positive pages become 1; pages past the end become the last page.
  def self.for(total_count:, requested_page:, per_page:)
    total_pages = [ (total_count.to_f / per_page).ceil, 1 ].max
    new(total_count:, per_page:, page: (Integer(requested_page.to_s, exception: false) || 1).clamp(1, total_pages))
  end

  def total_pages = [ (total_count.to_f / per_page).ceil, 1 ].max
  def offset = (page - 1) * per_page
  def previous_page = page > 1 ? page - 1 : nil
  def next_page = page < total_pages ? page + 1 : nil
end
