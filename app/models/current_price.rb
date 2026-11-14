# The latest known price of one printing in one series from one source, in the prices database (spec 081; spec 089).
# Keyed by printing (a catalog entry's id, with no foreign key: `prices.md`), source and series; the table is
# WITHOUT ROWID with no other index, so every lookup goes by printing, the key's first column.
#
# The daily refresh writes it with `upsert_all` and `delete_all` by key, which skip validations on purpose: each row comes
# from a validated `Prices::Sources::Quote`, and the table's own checks refuse the rest.
#
# @see file:prices.md
class CurrentPrice < PricesRecord
  self.primary_key = %i[catalog_entry_id price_source_id price_series_id]
end
