# Instance-wide settings; a single row (spec 004 FR-4).
class InstanceSetting < ApplicationRecord
  def self.current = first || create!
end
