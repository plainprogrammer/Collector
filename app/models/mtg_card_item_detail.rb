# frozen_string_literal: true

# MTGCardItemDetail is a delegated type model for Item.
# Stores physical-instance attributes specific to MTG cards.
#
# Condition grades: NM (Near Mint), LP (Lightly Played), MP (Moderately Played),
#                   HP (Heavily Played), DMG (Damaged)
# Finishes: nonfoil, foil, etched
# Languages: EN, JP, DE, FR, IT, ES, PT, KO, RU, ZHS, ZHT
#
# Grading fields (grading_service, grade) are only relevant when graded is true.
class MTGCardItemDetail < ApplicationRecord
  # Delegated type association
  has_one :item, as: :detail, touch: true, dependent: :destroy

  # Callbacks
  before_validation :generate_uuid, on: :create

  private

  def generate_uuid
    self.id ||= SecureRandom.uuid
  end
end
