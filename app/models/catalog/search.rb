# One page of card search results: identities with a searchable entry whose
# name or localized name contains the query (and in the chosen set), each
# listing its newest searchable entries in that set.
class Catalog::Search
  PER_PAGE = 12
  ENTRIES_PER_GROUP = 10
  MAX_QUERY_LENGTH = 100

  Group = Data.define(:identity, :entries, :total_entries)

  attr_reader :query, :set_code

  def initialize(query: nil, set_code: nil, page: nil)
    @query = query.to_s.strip.first(MAX_QUERY_LENGTH)
    @set_code = set_code.presence
    @requested_page = page
  end

  def active? = query.present? || set_code.present?

  def pagination
    @pagination ||= Catalog::Pagination.for(total_count: active? ? matching_entries.distinct.count(:catalog_identity_id) : 0,
      requested_page: @requested_page, per_page: PER_PAGE)
  end

  def groups
    return [] unless active?

    @groups ||= begin
      identities = Catalog::Identity.where(id: matching_entries.select(:catalog_identity_id))
        .order(:name, :id).offset(pagination.offset).limit(PER_PAGE).to_a
      entries = Catalog::Entry.searchable.in_set(set_code).where(catalog_identity_id: identities.map(&:id))
        .newest_first.includes(:set).to_a.group_by(&:catalog_identity_id)
      identities.map do |identity|
        listed = entries.fetch(identity.id, [])
        Group.new(identity:, entries: listed.first(ENTRIES_PER_GROUP), total_entries: listed.size)
      end.tap { |groups| Catalog::Entry.preload_extensions(groups.flat_map(&:entries)) }
    end
  end

  private
    def matching_entries
      scope = Catalog::Entry.searchable.in_set(set_code)
      query.present? ? scope.named_like(query) : scope
    end
end
