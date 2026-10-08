# A card's English printings for "Other printings" on the scanner (spec 009 Story 2), retired ones left out. With a
# confident artwork (spec 011 AC-7.5), the printings sharing it come first; then those matching what was read (set and
# number, then set, then number); each group in the catalog's newest-first order.
class Scanner::OtherPrintings
  SHOWN = 20

  def self.plain_number(number) = number.to_s.sub(/\A0+(?=\d)/, "").downcase.presence

  def initialize(identity:, set_code: nil, number: nil, artwork: nil)
    @identity = identity
    @set_code = set_code.to_s.downcase.presence
    @number = self.class.plain_number(number)
    @artwork = artwork
  end

  def entries
    @entries ||= begin
      all = Catalog::Entry.searchable.where(catalog_identity_id: @identity.id, language: "en").newest_first.includes(:set).to_a
      Catalog::Entry.preload_extensions(all)
      all.each_with_index.sort_by { |entry, index| [ group(entry), index ] }.map(&:first)
    end
  end

  def shown = entries.first(SHOWN)

  def rest = entries.drop(SHOWN)

  private
    def group(entry)
      return 0 if @artwork && entry.extension&.illustration_id == @artwork

      set = @set_code && entry.set.code.casecmp?(@set_code)
      number = @number && self.class.plain_number(entry.number) == @number
      if set && number then 1
      elsif set then 2
      elsif number then 3
      else 4
      end
    end
end
