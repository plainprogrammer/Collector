module Collector
  module Backup
    # manifest.json: what the backup holds and how to check it (decision 5, contracts/archive.md). Counts only, never a
    # name or an email address (hosted-door rule 2, AC-1.7). Version 1 describes the primary database in its six members;
    # version 2 adds a +prices+ member, a hash that describes the prices database the same way (spec 081 decision 6). The
    # top-level members always describe the primary.
    Manifest = Data.define(:backup_format_version, :taken_at, :schema_version, :snapshot_bytes, :snapshot_sha256, :counts, :prices)

    class Manifest
      Invalid = Class.new(StandardError)

      class UnknownVersion < StandardError
        attr_reader :version

        def initialize(version)
          @version = version
          super("backup format version #{version}")
        end
      end

      COUNT_NAMES = %w[accounts users lots].freeze
      PRICES_MEMBERS = %w[schema_version snapshot_bytes snapshot_sha256 counts].freeze # the members of the prices hash
      PRICES_COUNT_NAMES = %w[current_prices price_changes].freeze # the prices tables a manifest counts

      # Version 1 has no prices member (spec 081 decision 6).
      def initialize(prices: nil, **members) = super

      # The manifest of a backup taken from +snapshot+ and, when given, +prices+ (both Snapshot): version 2 with the prices
      # member, else version 1.
      #
      # @param snapshot [Snapshot] the primary database's snapshot file
      # @param taken_at [Time] when the backup was taken
      # @param prices [Snapshot, nil] the prices database's snapshot file
      # @return [Manifest]
      def self.for(snapshot, taken_at:, prices: nil)
        new(backup_format_version: prices ? 2 : 1, taken_at: taken_at.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
          schema_version: snapshot.schema_versions.max_by(&:to_i), snapshot_bytes: snapshot.path.size,
          snapshot_sha256: Digest::SHA256.file(snapshot.path).hexdigest, counts: snapshot.counts,
          prices: prices && { "schema_version" => prices.schema_versions.max_by(&:to_i), "snapshot_bytes" => prices.path.size,
            "snapshot_sha256" => Digest::SHA256.file(prices.path).hexdigest, "counts" => prices.counts(PRICES_COUNT_NAMES) })
      end

      # The archive's snapshot entries this manifest describes, in archive order: [name, bytes, sha256].
      #
      # @return [Array<Array>] one entry for version 1, two (primary, prices) for version 2
      def entries
        [ [ Archive::SNAPSHOT, snapshot_bytes, snapshot_sha256 ] ] +
          (prices ? [ [ Archive::PRICES, prices["snapshot_bytes"], prices["snapshot_sha256"] ] ] : [])
      end

      # The version is read first: a manifest of a version this release doesn't know may have other members (AC-3.4).
      #
      # @param text [String] the manifest's JSON
      # @return [Manifest]
      # @raise [UnknownVersion] when the backup format version isn't one this release knows
      # @raise [Invalid] when the text isn't JSON, or its members or their types differ from the format's
      def self.parse(text)
        data = JSON.parse(text)
        raise Invalid, "not an object" unless data.is_a?(Hash) && data["backup_format_version"].is_a?(Integer)
        raise UnknownVersion.new(data["backup_format_version"]) unless FORMAT_VERSIONS.include?(data["backup_format_version"])
        expected = members.map(&:to_s) - (data["backup_format_version"] == 1 ? [ "prices" ] : [])
        raise Invalid, "the members differ from the format's" unless data.keys.sort == expected.sort

        new(**data.transform_keys(&:to_sym)).tap { raise Invalid, "a member has the wrong type" unless it.valid? }
      rescue JSON::ParserError => error
        raise Invalid, error.message
      end

      # Whether every member has its type: the prices member is absent in version 1 and well formed in version 2.
      def valid?
        taken_at.is_a?(String) && schema_version.is_a?(String) && snapshot_bytes.is_a?(Integer) && snapshot_bytes >= 0 &&
          /\A\h{64}\z/.match?(snapshot_sha256.to_s) && counts.is_a?(Hash) && counts.keys.sort == COUNT_NAMES.sort &&
          counts.values.all?(Integer) && (backup_format_version == 1 ? prices.nil? : valid_prices?)
      end

      # The file's text; version 1 has no prices member.
      def to_json(*) = JSON.pretty_generate(to_h.then { prices ? it : it.except(:prices) })

      private

      def valid_prices?
        prices.is_a?(Hash) && prices.keys.sort == PRICES_MEMBERS.sort && prices["schema_version"].is_a?(String) &&
          prices["snapshot_bytes"].is_a?(Integer) && prices["snapshot_bytes"] >= 0 && /\A\h{64}\z/.match?(prices["snapshot_sha256"].to_s) &&
          prices["counts"].is_a?(Hash) && prices["counts"].keys.sort == PRICES_COUNT_NAMES.sort && prices["counts"].values.all?(Integer)
      end
    end
  end
end
