# Instance-wide settings; a single row, id 1, held to it by the database (spec 004 FR-4; #229, from #218 ruling 3).
class InstanceSetting < ApplicationRecord
  ID = 1 # the table's CHECK (id = 1) allows no other id

  # The row, made on first use. Two first reads at once can no longer make two rows: one insert wins, the other finds it.
  def self.current = find_by(id: ID) || create_or_find_by!(id: ID)
end
