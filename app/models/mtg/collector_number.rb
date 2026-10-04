require "did_you_mean"

# Collector numbers as printed: digits, then any letters or symbols ("117", "117a", "52★") (spec 009 AC-5.3).
module MTG::CollectorNumber
  SHAPE = /\A0*(\d+)(\D*)\z/

  module_function

  # True when the digits differ by one digit added, dropped or changed, ignoring leading zeros, and whatever follows
  # the digits matches exactly.
  def one_digit_apart?(printed, read)
    a, b = SHAPE.match(printed.to_s), SHAPE.match(read.to_s)
    return false unless a && b && a[2].casecmp?(b[2])

    DidYouMean::Levenshtein.distance(a[1], b[1]) == 1
  end
end
