# Folds a card name, or text read off a card, to the key names are compared by (spec 007 AC-3.4):
# NFKC, ligatures, diacritics, case and apostrophes, then every other run of punctuation or space to one space.
module Catalog::NameKey
  LIGATURES = { "Æ" => "AE", "æ" => "ae", "Œ" => "OE", "œ" => "oe", "ß" => "ss" }.freeze

  module_function

  def call(text)
    folded = text.to_s.unicode_normalize(:nfkc).gsub(Regexp.union(LIGATURES.keys), LIGATURES)
    folded.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase
      .gsub(/['’‘`]/, "").gsub(/[^\p{L}\p{N}]+/, " ").strip
  end
end
