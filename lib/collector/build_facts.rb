module Collector
  # The facts of the running build that every page's footer shows in Collector's licence line (spec 084): its version,
  # the commit it was built from and the address of that commit's source. The image's build sets them as environment
  # variables (`COLLECTOR_VERSION`, `COLLECTOR_REVISION`, `COLLECTOR_SOURCE_URL`); a development checkout falls back to
  # git for the revision. Each fact is trimmed and checked, and one that fails its rule counts as not given, so no value
  # an image or an operator passes can break a page (spec 084 decision 6). The line also links the third-party
  # licences page (spec 087), whose address is {LICENCES_PATH}.
  #
  # `config/initializers/build_facts.rb` reads them once at boot; {.current} returns that reading. Specs replace it with
  # `build_facts(...)` (`spec/support/build_facts.rb`) and never through the process environment (decision 10).
  #
  # @see file:release-and-deploy.md
  # @see file:catalog-core.md
  class BuildFacts
    # Where the source is when the build names no address: the upstream repository (decision 5).
    UPSTREAM_SOURCE = "https://github.com/plainprogrammer/Collector"
    # The licence's text, independent of any forge (decision 2).
    LICENCE_URL = "https://www.gnu.org/licenses/agpl-3.0.html"
    # A release's number, `edge`, `pr-N`, `development`: what a tag or a builder may name, with nothing a page would
    # escape (decision 6).
    VERSION_RULE = /\A[0-9A-Za-z.+_-]{1,64}\z/
    # A full commit SHA. A short one is refused so that two builds can't show the same ambiguous prefix (decision 6).
    REVISION_RULE = /\A\h{40}\z/
    # The page that lists the third-party licences (spec 087). A constant, because `licence_parts` is in lib/ with no
    # route helpers; spec/requests/licences_link_spec.rb asserts it equals `licences_path`, so the route can't move
    # without it.
    LICENCES_PATH = "/licences"

    attr_reader :version, :revision, :source_url

    # @param version [String, nil] a checked version, or nil when none was given
    # @param revision [String, nil] a checked, lowercase 40-character SHA, or nil
    # @param source_url [String] an absolute `https` address
    def initialize(version:, revision:, source_url:)
      @version = version
      @revision = revision
      @source_url = source_url
    end

    # The facts this process runs with, read once at boot by `config/initializers/build_facts.rb`.
    #
    # @return [BuildFacts]
    def self.current = Rails.configuration.x.build_facts

    # Reads the facts from an environment. Each fact stands alone: in development, a version not given is
    # `development` and a revision not given is asked of `git`; elsewhere git is never asked (spec 084 decision 4).
    # No query, no request; it runs git at most once, in development.
    #
    # @param env [#[]] the variables, as `ENV` holds them
    # @param rails_env [String, #to_s] the Rails environment's name
    # @param git [#call] answers `HEAD`'s SHA, or nil; it may raise, and is called only in development
    # @return [BuildFacts]
    def self.read(env:, rails_env:, git: method(:git_head))
      version = cleaned(env["COLLECTOR_VERSION"], VERSION_RULE)
      revision = cleaned(env["COLLECTOR_REVISION"], REVISION_RULE)
      if rails_env.to_s == "development"
        version ||= "development"
        revision ||= cleaned(asked(git), REVISION_RULE)
      end
      new(version:, revision: revision&.downcase, source_url: https(env["COLLECTOR_SOURCE_URL"]) || UPSTREAM_SOURCE)
    end

    # The revision's first 7 characters, as the line shows it.
    #
    # @return [String, nil]
    def short_revision = revision&.first(7)

    # The licence line in reading order as `[text, address]` parts, the address nil where the text isn't a link, the
    # shape the footer renders for every line. The links sit on the fixed words "AGPL-3.0", "source code" and
    # "third-party licences", never found by searching the text, so a version that contains them moves nothing (spec 084
    # decision 2, AC-2.13, which now has three links; the third is spec 087 decision 1).
    #
    # @return [Array<Array(String, String), Array(String, nil)>]
    def licence_parts
      [ [ "#{name} is free software under the ", nil ], [ "AGPL-3.0", LICENCE_URL ], [ ". Get the ", nil ],
        [ "source code", source_url ], [ ".", nil ], [ " Read the ", nil ], [ "third-party licences", LICENCES_PATH ],
        [ ".", nil ] ]
    end

    # scrub: a byte that isn't UTF-8 would make match? and URI.parse raise, and this runs at boot (decision 6).
    def self.cleaned(value, rule)
      value = value.to_s.scrub.strip
      value if value.match?(rule)
    end

    def self.https(value)
      uri = URI.parse(value.to_s.scrub.strip)
      uri.to_s if uri.is_a?(URI::HTTPS) && uri.host.present?
    rescue URI::Error
      nil
    end

    def self.asked(git)
      git.call
    rescue StandardError
      nil
    end

    def self.git_head
      head = IO.popen(%w[git rev-parse HEAD], chdir: Rails.root.to_s, err: File::NULL, &:read)
      head if Process.last_status.success?
    end
    private_class_method :cleaned, :https, :asked, :git_head

    private
      # "Collector 0.3.0 (a9f6de7)", "Collector 0.3.0", "Collector (unknown version, a9f6de7)" or
      # "Collector (unknown version)" (spec 084 decision 2's table).
      def name
        return "Collector #{version}#{" (#{short_revision})" if short_revision}" if version

        "Collector (#{[ "unknown version", short_revision ].compact.join(", ")})"
      end
  end
end
