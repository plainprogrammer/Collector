# How Magic cards are collected: finishes, conditions and the category name (spec 004 FR-6).
module MTG::Collecting
  CATEGORY_NAME = "Magic: The Gathering"
  CONDITIONS = {
    "near_mint" => [ "Near mint", "NM" ], "lightly_played" => [ "Lightly played", "LP" ],
    "moderately_played" => [ "Moderately played", "MP" ], "heavily_played" => [ "Heavily played", "HP" ],
    "damaged" => [ "Damaged", "DMG" ]
  }.freeze
  SPECIAL_FINISHES = %w[foil etched].freeze
  FINISH_ORDER = %w[nonfoil foil etched].freeze

  def self.category_name = CATEGORY_NAME
  def self.conditions = CONDITIONS
  def self.special_finishes = SPECIAL_FINISHES
  def self.finish_label(finish) = finish.to_s.humanize

  def self.finishes_for(entry)
    Catalog::Entry.preload_extensions([ entry ]) if entry.extension.nil?
    Array(entry.extension&.finishes).sort_by { |finish| [ FINISH_ORDER.index(finish) || FINISH_ORDER.size, finish ] }
  end
end
