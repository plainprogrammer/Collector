# One row of price history, in the prices database: the price of a printing in a series from a source on the day it
# differed from the last one recorded; a row with no cents records that the price went away that day (spec 081; spec
# 089). WITHOUT ROWID, keyed by printing, source, series and day, with no other index. Written by the daily refresh with
# `upsert_all` on that key, so a second write for the same day replaces the first (validations are skipped on purpose,
# as for `CurrentPrice`).
#
# @see file:prices.md
class PriceChange < PricesRecord
  self.primary_key = %i[catalog_entry_id price_source_id price_series_id recorded_on]
end
