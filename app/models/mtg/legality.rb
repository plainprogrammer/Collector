# Paper formats shown on a card page, in order (spec 004 AC-8.8).
module MTG::Legality
  FORMATS = %w[standard pioneer modern legacy vintage pauper commander oathbreaker premodern].freeze
  WORDS = { "legal" => "Legal", "not_legal" => "Not legal", "banned" => "Banned", "restricted" => "Restricted" }.freeze

  def self.rows(legalities) = FORMATS.map { |format| [ format.titleize, legalities.fetch(format, "not_legal") ] }
  def self.word(status) = WORDS.fetch(status, "Not legal")
end
