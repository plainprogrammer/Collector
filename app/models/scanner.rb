# The card scanner's records (spec 009): the account's sitting and its entries. Measurement mode's files are plain
# Ruby (Scanner::MeasurementRun) and keep no table.
module Scanner
  def self.table_name_prefix = "scanner_"
end
