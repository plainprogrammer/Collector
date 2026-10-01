# One lot marked in a bulk selection: selected, or excepted from "every matching lot" (spec 006 FR-4).
class BulkSelection::Mark < ApplicationRecord
  belongs_to :bulk_selection
  belongs_to :account
  belongs_to :lot
end
