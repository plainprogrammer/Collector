# Market prices as the core knows them: which price sources exist and which collectible each one is for. A source
# implements the contract in `Prices::Sources`, which is the one place the contract is written down; this module only
# finds sources, as `Catalog.sources` finds a collectible's catalog source (spec 085 decision 11).
#
# @see file:prices.md
module Prices
  # Registered price sources, by key => class name, set in `config/initializers/prices.rb`.
  mattr_accessor :sources, default: {}

  # The class of a registered price source.
  #
  # @param key [String] the source's key, as registered
  # @return [Class] a class that implements `Prices::Sources`
  # @raise [ArgumentError] when no source is registered under the key
  def self.source_class(key)
    sources.fetch(key) { raise ArgumentError, "unknown price source: #{key}" }.constantize
  end

  # The price sources of one collectible type, in key order.
  #
  # @param collectible_type [String] a key of `Catalog.sources`
  # @return [Array<Class>] empty when the type has no price source
  def self.sources_for(collectible_type)
    sources.keys.sort.map { |key| source_class(key) }.select { |source| source.collectible_type == collectible_type }
  end
end
