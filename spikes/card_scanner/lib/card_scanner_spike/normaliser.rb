module CardScannerSpike
  # Folds a card name or OCR text to a comparison key: NFKC, ligatures,
  # diacritics, case, apostrophes, punctuation and whitespace.
  module Normaliser
    LIGATURES = { "Æ" => "AE", "æ" => "ae", "Œ" => "OE", "œ" => "oe", "ß" => "ss" }.freeze

    module_function

    def call(text)
      folded = text.to_s.unicode_normalize(:nfkc).gsub(Regexp.union(LIGATURES.keys), LIGATURES)
      folded.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase
        .gsub(/['’‘`]/, "").gsub(/[^\p{L}\p{N}]+/, " ").strip
    end
  end
end
