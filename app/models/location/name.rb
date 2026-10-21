# A location's name as one function (spec 029 decision 5): what a collector types and what a file holds are made
# into the same form before they are compared, judged or stored. The same sets are in the format document and in
# v2.schema.json; spec/models/location/name_parity_spec.rb proves the three agree.
module Location::Name
  MAX_LENGTH = 60
  LEFT_OVER = /[\p{Cc}\p{Cf}]/

  # Steps 1 and 2: NFC, then the White_Space at either end removed and each run inside made one U+0020. Text that
  # isn't valid UTF-8 is returned as it is (unicode_normalize would raise); .fault refuses it.
  def self.normalise(text)
    text = text.to_s
    return text unless text.valid_encoding?

    text.unicode_normalize(:nfc).gsub(/\A\p{White_Space}+|\p{White_Space}+\z/, "").gsub(/\p{White_Space}+/, " ")
  end

  # The comparison key: Unicode full case folding of a normalised name. For uniqueness and matching only.
  def self.key(normalised) = normalised.valid_encoding? ? normalised.downcase(:fold) : normalised

  # Steps 3 to 5 for a normalised name: why it is refused, or nil.
  def self.fault(normalised)
    return :control unless normalised.valid_encoding?
    return :blank if normalised.empty?
    return :control if normalised.match?(LEFT_OVER)

    :too_long if normalised.length > MAX_LENGTH
  end
end
