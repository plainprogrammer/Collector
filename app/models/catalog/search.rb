# One page of card search results: identities with a searchable entry whose
# name or localized name contains the query (and in the chosen set), each
# listing its newest searchable entries in that set.
class Catalog::Search
  PER_PAGE = 12
  ENTRIES_PER_GROUP = 10
  MAX_QUERY_LENGTH = 100

  Group = Data.define(:identity, :entries, :total_entries)

  attr_reader :query, :set_code

  # @param collectible_type [String, nil] limits the results to one collectible type's printings (the add-a-proxy page lists
  #   only the deck's own; spec 068 decision 3); nil searches every type, as the card search does
  def initialize(query: nil, set_code: nil, page: nil, collectible_type: nil)
    @query = query.to_s.strip.first(MAX_QUERY_LENGTH)
    @set_code = set_code.presence
    @requested_page = page
    @collectible_type = collectible_type.presence
  end

  def active? = query.present? || set_code.present?

  def pagination
    @pagination ||= Catalog::Pagination.for(total_count: active? ? matching_entries.distinct.count(:catalog_identity_id) : 0,
      requested_page: @requested_page, per_page: PER_PAGE)
  end

  # The page's cards, each with its newest printings (at most `ENTRIES_PER_GROUP`) and their extension records preloaded; none
  # when neither a name nor a set was given.
  #
  # @return [Array<Group>]
  def groups
    return [] unless active?

    @groups ||= begin
      identities = Catalog::Identity.where(id: matching_entries.select(:catalog_identity_id))
        .order(:name, :id).offset(pagination.offset).limit(PER_PAGE).to_a
      entries = entries_scope.where(catalog_identity_id: identities.map(&:id))
        .newest_first.includes(:set).to_a.group_by(&:catalog_identity_id)
      identities.map do |identity|
        listed = entries.fetch(identity.id, [])
        Group.new(identity:, entries: listed.first(ENTRIES_PER_GROUP), total_entries: listed.size)
      end.tap { |groups| Catalog::Entry.preload_extensions(groups.flat_map(&:entries)) }
    end
  end

  private
    def entries_scope
      scope = Catalog::Entry.searchable.in_set(set_code)
      @collectible_type ? scope.where(collectible_type: @collectible_type) : scope
    end

    def matching_entries
      query.present? ? entries_scope.named_like(query) : entries_scope
    end
end
