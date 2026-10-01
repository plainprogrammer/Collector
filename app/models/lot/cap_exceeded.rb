# A change that would put more than 9,999 copies in one lot (spec 004 FR-6). It names the lot that
# would overflow, first in the table's order (spec 006 AC-6.4, AC-7.5).
class Lot::CapExceeded < StandardError
  attr_reader :lot

  def initialize(lot)
    @lot = lot
    super("#{lot.entry.name} would have more than #{Lot::MAX_QUANTITY} copies in one lot")
  end
end
