# The connection to the prices database, the instance's fifth SQLite file (spec 081 decisions 1 and 5; ADR 0029).
# Every model of a price table inherits from it. Prices are global, like the catalog: no account scopes them, and no
# query joins this file with the primary one. A printing is named by its catalog entry's id, with no foreign key
# (spec 081 decision 4). This class has no models yet: #364 to #366 add them.
class PricesRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :prices }
end
