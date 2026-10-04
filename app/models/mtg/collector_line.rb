# Reads a card's collector line from OCR text (spec 007 FR-4, AC-3.6, AC-3.7). Printed shapes: pre-M15
# `NNN/TTT`; M15–ONE `NNN/TTT R` then `SET • EN`; MOM and later `R NNNN` then `SET • EN`. OCR glues the
# rarity to the number, drops the slash and misreads the bullet, so the number is tried against several
# patterns in turn and the set line accepts any one- or two-character mark before a known language.
# The foil mark is reported as read; the scanner shows it as a hint for the finish, never a choice (spec 009 AC-6.5).
module MTG::CollectorLine
  Result = Data.define(:set_code, :number, :language, :foil, :format)

  LANGUAGES = { "EN" => "en", "JP" => "ja", "DE" => "de", "FR" => "fr", "IT" => "it", "ES" => "es",
                "PT" => "pt", "RU" => "ru", "KO" => "ko", "CS" => "zhs", "CT" => "zht" }.freeze
  # Set codes that are also English words. The loose fallback skips them, because rules and flavour
  # text ("Add one") would otherwise read as a set; the SET • LANG shape still accepts them (AC-3.7).
  WORD_SET_CODES = %w[one war all ice big who mid].freeze
  LOOKALIKES = { "O" => "0", "D" => "0", "I" => "1", "L" => "1", "S" => "5", "B" => "8" }.freeze
  NUMBERISH = "[0-9ODILSB]"
  SLASH = %r{(?<![A-Z0-9])(#{NUMBERISH}{1,4})\s*/\s*#{NUMBERISH}{1,4}(?![A-Z0-9])}
  RARITY_FIRST = /(?<![A-Z0-9])[CURMSLTP]\s+(#{NUMBERISH}{1,4})([A-Z★]?)(?![A-Z0-9])/
  GLUED_RARITY = /(?<![A-Z0-9])[CURMSLTP]([0-9]#{NUMBERISH}{2,3})(?![A-Z0-9])/
  BARE_NUMBER = /(?<![A-Z0-9])(\d{1,4})(?![A-Z0-9])/
  SET_LINE = /(?<![A-Z0-9])([A-Z0-9]{3,5})[ \t]*(\S{1,2})?[ \t]*(#{LANGUAGES.keys.join("|")})(?![A-Z])/
  FOIL_MARKERS = %w[★ *].freeze

  module_function

  def parse(text, known_set_codes:)
    upper = text.to_s.unicode_normalize(:nfkc).upcase
    known = known_set_codes.to_set(&:upcase)
    line = set_line(upper, known)
    number, format = number(upper, before: line&.fetch(:at))
    Result.new(set_code: line ? line[:code] : loose_set_code(upper, known), number:,
      language: LANGUAGES[line&.fetch(:language)], foil: line && line[:marker] && FOIL_MARKERS.include?(line[:marker]), format:)
  end

  def set_line(upper, known)
    upper.to_enum(:scan, SET_LINE).each do
      match = Regexp.last_match
      code = resolve(match[1], known)
      return { code:, marker: match[2], language: match[3], at: match.begin(0) } if code
    end
    nil
  end

  def loose_set_code(upper, known)
    upper.split(/[^A-Z0-9]+/).each do |token|
      next if token.length < 3 || token.length > 5 || token.match?(/\A\d+\z/)

      code = resolve(token, known)
      return code if code && WORD_SET_CODES.exclude?(code.downcase)
    end
    nil
  end

  def resolve(code, known) = [ code, code.tr("0", "O"), code.tr("O", "0") ].find { known.include?(it) }

  def number(upper, before:)
    if (match = SLASH.match(upper)) then [ digits(match[1]), :slash ]
    elsif (match = RARITY_FIRST.match(upper)) then [ digits(match[1]) + match[2].downcase, :rarity_first ]
    elsif (match = GLUED_RARITY.match(upper)) then [ digits(match[1]), :glued_rarity ]
    elsif before && (last = upper[0, before].scan(BARE_NUMBER).last) then [ digits(last.first), :before_set_line ]
    else [ nil, nil ]
    end
  end

  def digits(token) = token.gsub(/[ODILSB]/, LOOKALIKES).sub(/\A0+(?=\d)/, "")
end
