Catalog::Pagination = Data.define(:total_count, :page, :per_page) do
  # Only decimal digits name a page, so "010" is page 10; anything else ("0x10", "1_0", "-1", "0", "", " 7")
  # becomes 1, and pages past the end become the last page (spec 002 AC-1.14; #204).
  DECIMAL = /\A\d+\z/

  def self.for(total_count:, requested_page:, per_page:)
    total_pages = [ (total_count.to_f / per_page).ceil, 1 ].max
    digits = requested_page.to_s
    requested = digits.match?(DECIMAL) ? digits.to_i : 1
    new(total_count:, per_page:, page: requested.clamp(1, total_pages))
  end

  def total_pages = [ (total_count.to_f / per_page).ceil, 1 ].max
  def offset = (page - 1) * per_page
  def previous_page = page > 1 ? page - 1 : nil
  def next_page = page < total_pages ? page + 1 : nil
end
