# What applying a file would do with the collector's locations (spec 029 decision 10): replace by comparison key. A
# version 1 file says nothing about locations (+names+ is nil), so theirs stay as they are and nothing here counts.
class CollectionImport::Locations
  Held = Data.define(:id, :name, :key)
  Renamed = Data.define(:held, :name)

  attr_reader :added, :renamed, :removed, :unchanged

  # +held+: the account's locations as Held. +names+: the file's names, each normalised on read, or nil for version 1.
  def initialize(held, names)
    @counted = !names.nil?
    @added = []
    @renamed = []
    @removed = []
    @unchanged = 0
    return unless @counted

    held_by_key = held.index_by(&:key)
    file = names.index_by { |name| Location::Name.key(name) }
    file.each do |key, name|
      kept = held_by_key[key]
      if kept.nil?
        @added << name
      elsif kept.name == name
        @unchanged += 1
      else
        @renamed << Renamed.new(held: kept, name:)
      end
    end
    @removed = held.reject { |location| file.key?(location.key) }
    @added.sort_by! { |name| [ Location::Name.key(name), name ] }
    @renamed.sort_by! { |renamed| [ renamed.held.key, renamed.name ] }
    @removed.sort_by! { |location| [ location.key, location.name ] }
  end

  def counted? = @counted

  def counts = { added: added.size, renamed: renamed.size, unchanged:, removed: removed.size }

  def nothing_to_change? = added.empty? && renamed.empty? && removed.empty?

  def removes? = removed.any?

  def listed_renamed = renamed.first(CollectionImport::LIST_LIMIT)

  def more_renamed = renamed.size - listed_renamed.size

  def listed_removed = removed.first(CollectionImport::LIST_LIMIT)

  def more_removed = removed.size - listed_removed.size

  # What the plan's fingerprint takes from the locations (decision 11, ruled 2026-10-21): the name of each added one; the
  # current name and the file's name of each renamed one; the name of each removed one. No id, and an unchanged one isn't
  # in it, so a location deleted and added again with the same spelling changes nothing (AC-9.9). The lists are already in
  # the order of the comparison key then the name, which is unique per account, so the part is the same every time. The
  # apply writes by the ids `replan` reads inside its transaction, so the fingerprint needs none.
  def fingerprint_part
    [ added, renamed.map { |item| [ item.held.name, item.name ] }, removed.map { |location| [ location.name ] } ]
  end
end
