require "json"
require "net/http"
require "openssl"
require "time"

module Collector
  # Deletes untagged versions of ghcr.io/plainprogrammer/collector that no tagged manifest list references, once
  # their orphan unit is past a 7-day grace period (spec 013, ADR 0011). Fails closed: anything it can't read or
  # understand stops the run before a delete. Stdlib only: loaded by bin/ghcr-cleanup without the app.
  module GhcrCleanup
    LIST_TYPES = %w[application/vnd.oci.image.index.v1+json
                    application/vnd.docker.distribution.manifest.list.v2+json].freeze
    IMAGE_TYPES = %w[application/vnd.oci.image.manifest.v1+json
                     application/vnd.docker.distribution.manifest.v2+json].freeze
    PLATFORMS = %w[linux/amd64 linux/arm64].freeze
    GRACE = 7 * 86_400

    class Failure < StandardError; end
    class Refused < Failure; end

    Version = Data.define(:id, :digest, :created_at, :tags) do
      def tagged? = tags.any?
      def label = tagged? ? "tag #{tags.join(", ")} (#{digest})" : digest
    end

    Manifest = Data.define(:media_type, :children, :platforms) do
      # The media type comes from Content-Type, falling back to the body's mediaType (FR-1).
      def self.parse(content_type, body)
        json = JSON.parse(body)
        raise Failure, "manifest is not a JSON object" unless json.is_a?(Hash)

        type = content_type.to_s.split(";").first.to_s.strip
        type = json["mediaType"].to_s if type.empty?
        entries = LIST_TYPES.include?(type) ? Array(json["manifests"]).grep(Hash) : []
        unless entries.all? { |entry| entry["digest"].is_a?(String) && entry["digest"].start_with?("sha256:") }
          raise Failure, "manifest names a child without a digest"
        end
        new(media_type: type, children: entries.map { |entry| entry["digest"] },
            platforms: entries.map { |entry| "#{entry.dig("platform", "os")}/#{entry.dig("platform", "architecture")}" })
      rescue JSON::ParserError
        raise Failure, "manifest is not JSON"
      end

      def list? = LIST_TYPES.include?(media_type)
      def known? = list? || IMAGE_TYPES.include?(media_type)
    end

    # An orphan unit; its manifest lists come first so an interrupted run leaves only standalone images (FR-1).
    Unit = Data.define(:lists, :images) do
      def members = lists + images
      def age(now) = now - members.map(&:created_at).max
      def past_grace?(now) = age(now) > GRACE
    end

    Plan = Data.define(:selected, :young, :counts)

    module_function

    def token_from(env)
      token = [ env["GH_TOKEN"], env["GITHUB_TOKEN"] ].find { |value| value && !value.empty? }
      token or raise Failure, "set GH_TOKEN (or GITHUB_TOKEN) to a token that can read the package"
    end

    # Checks every tagged version is a two-platform manifest list and returns the digests they reference.
    def referenced(tagged)
      tagged.each_with_object(Set.new) do |(version, manifest), digests|
        check_tagged!(version, manifest)
        digests.merge(manifest.children)
      end
    end

    def check_tagged!(version, manifest)
      raise Failure, "#{version.label} is #{manifest.media_type.inspect}, not a manifest list" unless manifest.list?
      return if manifest.platforms.sort == PLATFORMS

      raise Failure, "#{version.label} has platforms #{manifest.platforms.join(", ")}; expected #{PLATFORMS.join(" and ")}"
    end

    # Groups the candidates (untagged, unreferenced) into orphan units, merging units that share a member, and
    # splits them by the grace period. manifests holds every candidate's manifest by digest.
    def plan(versions:, referenced:, manifests:, now:)
      candidates = versions.reject { |version| version.tagged? || referenced.include?(version.digest) }
      root = candidates.to_h { |version| [ version.digest, version.digest ] }
      find = ->(digest) { root[digest] == digest ? digest : (root[digest] = find.(root[digest])) }
      candidates.each do |version|
        manifest = manifests.fetch(version.digest)
        raise Failure, "#{version.digest} is #{manifest.media_type.inspect}, which the cleanup does not know" unless manifest.known?

        manifest.children.each { |child| root[find.(child)] = find.(version.digest) if root.key?(child) }
      end
      units = candidates.group_by { |version| find.(version.digest) }.values.map do |members|
        lists, images = members.partition { |version| manifests.fetch(version.digest).list? }
        Unit.new(lists:, images:)
      end
      selected, young = units.partition { |unit| unit.past_grace?(now) }
      tagged = versions.count(&:tagged?)
      Plan.new(selected:, young:, counts: { tagged:, referenced: versions.size - tagged - candidates.size,
                                            young: young.sum { |unit| unit.members.size },
                                            selected: selected.sum { |unit| unit.members.size } })
    end

    def duration(seconds)
      days, rest = seconds.to_i.divmod(86_400)
      "#{days}d #{rest / 3600}h"
    end
  end
end
