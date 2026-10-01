# The collection table's order (spec 006 Story 3, FR-3): one allowlisted column and direction, applied
# in SQL before paging. The default order (the grid's, then finish, condition and price paid) breaks
# every tie, so the order is stable across pages. Only Arel nodes reach the query.
class CollectionTable::Sort
  COLUMNS = %w[name set condition quantity price].freeze
  DIRECTIONS = %w[asc desc].freeze

  attr_reader :column, :direction

  def self.parse(column, direction)
    return new(nil, "asc") unless COLUMNS.include?(column)

    new(column, DIRECTIONS.include?(direction) ? direction : "asc")
  end

  # The form a bulk selection stores: "condition-desc", or "" for the default order.
  def self.from_key(key)
    column, direction = key.to_s.split("-", 2)
    parse(column, direction)
  end

  def self.default_order
    [ asc(entries[:name]), desc(entries[:released_on]), asc(sets[:code]), asc(entries[:number]), asc(entries[:language]),
      asc(lots[:finish].eq(nil)), asc(rank(lots[:finish], &:finish_order)), asc(lots[:finish]),
      asc(lots[:condition].eq(nil)), asc(rank(lots[:condition]) { |vocabulary| vocabulary.conditions.keys }),
      asc(lots[:price_paid_cents].eq(nil)), asc(lots[:price_paid_cents]), asc(lots[:id]) ]
  end

  # Each collectible's own order for a column (its condition scale, its finishes); unknown values last.
  def self.rank(column)
    orders = Catalog.collecting.keys.index_with { |type| yield Catalog.collecting_for(type) }
    orders.each_with_object(Arel::Nodes::Case.new) do |(type, values), node|
      values.each_with_index { |value, index| node.when(entries[:collectible_type].eq(type).and(column.eq(value))).then(index) }
    end.else(orders.values.map(&:size).max.to_i)
  end

  def self.asc(node) = Arel::Nodes::Ascending.new(node)
  def self.desc(node) = Arel::Nodes::Descending.new(node)
  def self.lots = Lot.arel_table
  def self.entries = Catalog::Entry.arel_table
  def self.sets = Catalog::Set.arel_table

  def initialize(column, direction)
    @column, @direction = column, direction
  end

  def default? = column.nil?
  def key = default? ? "" : "#{column}-#{direction}"
  def to_params = default? ? {} : { sort: column, dir: direction }

  # How a header states the order; the default order reads as Name ascending (AC-3.1, AC-3.2).
  def aria_sort(header)
    return "none" unless header == (column || "name")

    direction == "asc" ? "ascending" : "descending"
  end

  # Where activating a header leads: its column ascending, or the sorted column reversed (AC-3.2).
  def toward(header) = self.class.new(header, aria_sort(header) == "ascending" ? "desc" : "asc")

  # Orders a lots relation that joins entry and set.
  def apply(scope) = scope.reorder(*leading, *self.class.default_order)

  private
    def leading
      klass = self.class
      case column
      when "name" then [ by(klass.entries[:name]) ]
      when "set" then [ by(klass.sets[:code]), by(klass.entries[:number]) ]
      when "condition"
        [ klass.asc(klass.lots[:condition].eq(nil)), by(klass.rank(klass.lots[:condition]) { |vocabulary| vocabulary.conditions.keys }) ]
      when "quantity" then [ by(klass.lots[:quantity]) ]
      when "price" then [ klass.asc(klass.lots[:price_paid_cents].eq(nil)), by(klass.lots[:price_paid_cents]) ]
      else []
      end
    end

    def by(node) = direction == "asc" ? self.class.asc(node) : self.class.desc(node)
end
