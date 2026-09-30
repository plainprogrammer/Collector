module CardScannerSpike
  # Parses OCR text from a card's collector line (FR-3). Printed formats:
  # M15–ONE `NNN/TTT R` then `SET • EN`; MOM and later `R NNNN` then `SET • EN`.
  module CollectorLine
    Result = Data.define(:set_code, :number, :language, :foil, :format)

    LANGUAGES = { "EN" => "en", "JP" => "ja", "DE" => "de", "FR" => "fr", "IT" => "it", "ES" => "es",
                  "PT" => "pt", "RU" => "ru", "KO" => "ko", "CS" => "zhs", "CT" => "zht" }.freeze
    LOOKALIKES = { "O" => "0", "D" => "0", "I" => "1", "L" => "1", "S" => "5", "B" => "8" }.freeze
    NUMBERISH = "[0-9ODILSB]"
    SLASH = %r{(?<![A-Z0-9])(#{NUMBERISH}{1,4})\s*/\s*#{NUMBERISH}{1,4}(?![A-Z0-9])}
    RARITY_FIRST = /(?<![A-Z0-9])[CURMSLTP]\s+(#{NUMBERISH}{1,4})([A-Z★]?)(?![A-Z0-9])/
    SET_LINE = /(?<![A-Z0-9])([A-Z0-9]{3,5})\s*([•·*★.«»°~-])\s*([A-Z]{2})(?![A-Z])/ # OCR reads • as « at times
    FOIL_MARKERS = %w[★ *].freeze

    module_function

    def parse(text, known_set_codes:)
      upper = text.to_s.unicode_normalize(:nfkc).upcase
      known = known_set_codes.to_set(&:upcase)
      set_code, marker, language = set_line(upper, known) || [ loose_set_code(upper, known), nil, nil ]
      number, format = number(upper)
      Result.new(set_code:, number:, language: LANGUAGES[language], foil: marker && FOIL_MARKERS.include?(marker), format:)
    end

    def set_line(upper, known)
      upper.scan(SET_LINE).each do |code, marker, language|
        resolved = resolve(code, known)
        return [ resolved, marker, language ] if resolved
      end
      nil
    end

    def loose_set_code(upper, known)
      upper.split(/[^A-Z0-9]+/).each do |token|
        next if token.length < 3 || token.length > 5 || token.match?(/\A\d+\z/)

        resolved = resolve(token, known)
        return resolved if resolved
      end
      nil
    end

    def resolve(code, known) = [ code, code.tr("0", "O"), code.tr("O", "0") ].find { known.include?(it) }

    def number(upper)
      if (match = SLASH.match(upper)) then [ digits(match[1]), :slash ]
      elsif (match = RARITY_FIRST.match(upper)) then [ digits(match[1]) + match[2].downcase, :rarity_first ]
      else [ nil, nil ]
      end
    end

    def digits(token) = token.gsub(/[ODILSB]/, LOOKALIKES).sub(/\A0+(?=\d)/, "")
  end
end
