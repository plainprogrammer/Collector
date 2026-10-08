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

    # The packages API and the registry. Error messages name the request, never the token.
    class Client
      API = "https://api.github.com/users/plainprogrammer/packages/container/collector/versions".freeze
      REGISTRY = "https://ghcr.io/v2/plainprogrammer/collector/manifests/".freeze
      PULL_TOKEN = "https://ghcr.io/token?scope=repository:plainprogrammer/collector:pull".freeze
      PER_PAGE = 100
      ACCEPT = (LIST_TYPES + IMAGE_TYPES).join(", ").freeze
      USER_AGENT = "collector-ghcr-cleanup (+https://github.com/plainprogrammer/Collector)".freeze

      def initialize(token:)
        @token = token
      end

      # Every page, by number on the /users/ path; the Link header points at a /user/{id}/ path (FR-3).
      def versions
        (1..).each_with_object([]) do |page, all|
          url = "#{API}?per_page=#{PER_PAGE}&page=#{page}"
          batch = parse_versions(url, json(request(Net::HTTP::Get, url, github_headers), url))
          all.concat(batch)
          break all if batch.size < PER_PAGE
        end
      end

      def manifest(digest)
        url = REGISTRY + digest
        response = request(Net::HTTP::Get, url, registry_headers)
        raise Failure, "GET #{url} answered #{response.code}" unless response.code == "200"

        Manifest.parse(response["content-type"], response.body)
      end

      def fetchable?(digest)
        url = REGISTRY + digest
        code = request(Net::HTTP::Head, url, registry_headers).code
        return code == "200" if %w[200 404].include?(code)

        raise Failure, "HEAD #{url} answered #{code}"
      end

      # :deleted, or :gone when GitHub answers 404 (already deleted, AC-3.9); raises Refused otherwise.
      def delete(version)
        url = "#{API}/#{version.id}"
        code = request(Net::HTTP::Delete, url, github_headers).code
        return :deleted if code == "204"
        return :gone if code == "404"

        raise Refused, "DELETE #{url} (#{version.digest}) answered #{code}"
      end

      private

      def request(verb, url, headers)
        uri = URI(url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
          http.request(verb.new(uri, headers))
        end
      rescue IOError, SystemCallError, SocketError, Timeout::Error, OpenSSL::SSL::SSLError, Net::ProtocolError,
             Net::HTTPBadResponse => e
        raise Failure, "#{verb::METHOD} #{url} failed: #{e.class}"
      end

      def json(response, url)
        raise Failure, "GET #{url} answered #{response.code}" unless response.code == "200"

        JSON.parse(response.body)
      rescue JSON::ParserError
        raise Failure, "GET #{url} did not return JSON"
      end

      def parse_versions(url, entries)
        raise Failure, "GET #{url} did not return a version list" unless entries.is_a?(Array)

        entries.map do |entry|
          tags = entry.dig("metadata", "container", "tags") if entry.is_a?(Hash)
          unless tags.is_a?(Array) && entry["id"].is_a?(Integer) && entry["name"].to_s.start_with?("sha256:")
            raise Failure, "GET #{url} did not return a version list"
          end

          Version.new(id: entry["id"], digest: entry["name"], created_at: Time.iso8601(entry["created_at"].to_s), tags:)
        rescue ArgumentError, TypeError
          raise Failure, "GET #{url} did not return a version list"
        end
      end

      def pull_token
        @pull_token ||= begin
          body = json(request(Net::HTTP::Get, PULL_TOKEN, { "User-Agent" => USER_AGENT }), PULL_TOKEN)
          raise Failure, "GET #{PULL_TOKEN} returned no token" unless body.is_a?(Hash) && body["token"].is_a?(String)

          body["token"]
        end
      end

      def github_headers
        { "Authorization" => "Bearer #{@token}", "Accept" => "application/vnd.github+json",
          "X-GitHub-Api-Version" => "2022-11-28", "User-Agent" => USER_AGENT }
      end

      def registry_headers
        { "Authorization" => "Bearer #{pull_token}", "Accept" => ACCEPT, "User-Agent" => USER_AGENT }
      end
    end

    # One run: read everything, plan, report, and (with delete: true) delete and check every tag afterwards.
    class Run
      def initialize(client:, out:, now: Time.now, delete: false)
        @client, @out, @now, @delete = client, out, now, delete
      end

      # Returns the plan; raises Failure when the run must fail (nothing deleted, or nothing after the failure).
      def call
        versions = @client.versions
        tagged = versions.select(&:tagged?)
        referenced = GhcrCleanup.referenced(tagged.to_h { |version| [ version, read(version) ] })
        candidates = versions.reject { |version| version.tagged? || referenced.include?(version.digest) }
        manifests = candidates.to_h { |version| [ version.digest, read(version) ] }
        plan = GhcrCleanup.plan(versions:, referenced:, manifests:, now: @now)
        report(plan)
        delete(plan, tagged) if @delete
        plan
      end

      private

      def read(version)
        @client.manifest(version.digest)
      rescue Failure => e
        raise Failure, "#{version.label}: #{e.message}"
      end

      def report(plan)
        @out.puts(@delete ? "Deleting orphans past the 7-day grace period." : "Dry run: nothing is deleted (pass --delete to delete).")
        plan.selected.each { |unit| describe(unit, "select") }
        plan.young.each { |unit| describe(unit, "too young") }
        counts = plan.counts
        @out.puts("#{counts.values.sum} versions: #{counts[:tagged]} tagged, #{counts[:referenced]} referenced, " \
                  "#{counts[:young]} too young, #{counts[:selected]} selected")
      end

      def describe(unit, verdict)
        age = GhcrCleanup.duration(unit.age(@now))
        unit.members.each do |version|
          kind = unit.lists.include?(version) ? "orphan manifest list" : "unreferenced image"
          @out.puts("#{verdict} #{version.digest} created #{version.created_at.utc.iso8601} tags (none): #{kind}, unit age #{age}")
        end
      end

      def delete(plan, tagged)
        removed, refusal = delete_all(plan.selected.flat_map(&:members))
        problems = removed.positive? ? check(tagged) : []
        raise Failure, [ refusal, *problems ].compact.join("\n") if refusal || problems.any?
      end

      # Returns [versions removed, failure message or nil]; stops at the first refusal or failed request (AC-3.6),
      # so the post-delete check still runs when something was removed before it.
      def delete_all(members)
        removed = 0
        members.each do |version|
          result = @client.delete(version)
          removed += 1
          @out.puts("#{result == :gone ? "already deleted" : "deleted"} #{version.digest}")
        end
        [ removed, nil ]
      rescue Failure => e
        [ removed, e.message ]
      end

      # AC-2.4: deleting a child leaves its tagged list intact, so check every child is still in the registry.
      def check(tagged)
        tagged.flat_map do |version|
          manifest = read(version)
          GhcrCleanup.check_tagged!(version, manifest)
          manifest.children.reject { |child| @client.fetchable?(child) }.map { |child| "#{version.label}: child #{child} is missing" }
        rescue Failure => e
          [ e.message ]
        end
      end
    end
  end
end
