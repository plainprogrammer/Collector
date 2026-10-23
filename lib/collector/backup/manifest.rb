module Collector
  module Backup
    # manifest.json: what the backup holds and how to check it (decision 5, contracts/archive.md). Counts only, never a
    # name or an email address (hosted-door rule 2, AC-1.7).
    Manifest = Data.define(:backup_format_version, :taken_at, :schema_version, :snapshot_bytes, :snapshot_sha256, :counts)

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

      def self.for(snapshot, taken_at:)
        new(backup_format_version: FORMAT_VERSION, taken_at: taken_at.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
          schema_version: snapshot.schema_versions.max_by(&:to_i), snapshot_bytes: snapshot.path.size,
          snapshot_sha256: Digest::SHA256.file(snapshot.path).hexdigest, counts: snapshot.counts)
      end

      # The version is read first: a manifest of a version this release doesn't know may have other members (AC-3.4).
      def self.parse(text)
        data = JSON.parse(text)
        raise Invalid, "not an object" unless data.is_a?(Hash) && data["backup_format_version"].is_a?(Integer)
        raise UnknownVersion.new(data["backup_format_version"]) unless FORMAT_VERSIONS.include?(data["backup_format_version"])
        raise Invalid, "the members differ from the format's" unless data.keys.sort == members.map(&:to_s).sort

        new(**data.transform_keys(&:to_sym)).tap { raise Invalid, "a member has the wrong type" unless it.valid? }
      rescue JSON::ParserError => error
        raise Invalid, error.message
      end

      def valid?
        taken_at.is_a?(String) && schema_version.is_a?(String) && snapshot_bytes.is_a?(Integer) && snapshot_bytes >= 0 &&
          /\A\h{64}\z/.match?(snapshot_sha256.to_s) && counts.is_a?(Hash) && counts.keys.sort == COUNT_NAMES.sort &&
          counts.values.all?(Integer)
      end

      def to_json(*) = JSON.pretty_generate(to_h)
    end
  end
end
