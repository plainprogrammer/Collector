module Collector
  class ThirdPartyLicences
    # Judges the components of {ThirdPartyLicences.build}'s sections against the allowed list and the named exceptions in
    # `config/licence_policy.yml` (spec 091), as a list of problems each naming its offender, the licence and the file.
    #
    # Every input is injected, so a spec shows each rule failing on a small fixture; {.for_repository} builds the real ones
    # and the `licences:check` task prints the problems. A component passes if any one of its identifiers is allowed (spec 091
    # decision 2); one with none, or with a string that is not exactly an allowed id, fails (decision 5). A named exception
    # may instead require every licence of its gem to be allowed (`all_required`, spec 091 decision 3). Nothing here reads
    # a gem or a licence file: the one reader is {ThirdPartyLicences} (no second reader of the bundle).
    #
    # @see file:catalog-core.md
    # @see file:0031-a-dependency-licence-is-a-decision.md
    class Policy
      # The policy file, relative to `Rails.root`.
      PATH = "config/licence_policy.yml".freeze

      # The decision the failure messages point at: ADR 0031, not the policy YAML, holds the rule (any one of several
      # licences, every group, exceptions that go stale); the YAML holds only the list and the reasons.
      DECISION = "ADR 0031".freeze

      # A named exception, as the rules use it: the `gem`, its `licences` (sorted, a set) and whether its list is `all_required`.
      # Its `reason` is for the reader of the file; no rule reads it.
      Exemption = Data.define(:gem, :licences, :all_required)

      class << self
        # The policy of this repository: the file at `policy_path`, the sections of the running bundle and manifest, and the
        # lockfile's gem names.
        #
        # Reads the policy and, unless `sections` is given, every licence file {ThirdPartyLicences.build} reads (about 400 KB).
        #
        # @param policy_path [String, Pathname] the policy file; default `config/licence_policy.yml`
        # @param sections [Array<ThirdPartyLicences::Section>] the components to judge; default the real ones
        # @return [Policy]
        # @raise [SystemCallError] when the policy file can't be read
        # @raise [Psych::Exception] when it isn't valid YAML or holds more than plain data
        def for_repository(policy_path: Rails.root.join(PATH), sections: ThirdPartyLicences.build.sections)
          new(data: ThirdPartyLicences.load_manifest(policy_path), path: display_path(policy_path), sections:, locked_names:)
        end

        # The gem names the lockfile holds, once each.
        #
        # A gem the lockfile names for several platforms repeats there (`ffi`, `sqlite3`); `bundler` is in the bundle and
        # not in the lockfile, so it is never among them.
        #
        # @return [Array<String>]
        def locked_names
          Bundler::LockfileParser.new(Bundler.default_lockfile.read).specs.map(&:name).uniq
        end

        private

        # The path as a message prints it: relative to the application when it is inside it.
        def display_path(path) = path.to_s.delete_prefix("#{Rails.root}/")
      end

      # @param data [Hash{String=>Array<Hash>}, Object] the loaded policy: `allowed` (each `id`, `reason`) and `exceptions`
      #   (each `gem`, `licences`, `reason`, optional `all_required`); anything but a mapping is a problem, not a crash
      # @param path [String] the policy's path, as the messages print it
      # @param sections [Array<ThirdPartyLicences::Section>] what {ThirdPartyLicences.build} returns
      # @param locked_names [Array<String>] the gem names the lockfile holds, once each
      def initialize(data:, path:, sections:, locked_names:)
        @data = data
        @path = path.to_s
        @sections = sections
        @locked_names = locked_names
      end

      # How many components the sections hold, which is what a passing run reports it judged.
      #
      # @return [Integer]
      def component_count = components.size

      # What is off the policy, one sentence per offender, each naming it, its licence and the policy file.
      #
      # Pure of side effects. While the policy's own shape is wrong it reports only that, because judging against a
      # malformed list would blame every gem. Otherwise the judged sentences come first, in the order
      # {ThirdPartyLicences.build} lists the components, and the stale-exception sentences follow, in the policy file's order.
      #
      # @return [Array<String>] empty when everything agrees; the policy's shape problems alone when it is malformed
      def problems
        shape = shape_problems
        return shape if shape.any?

        judge_problems + exemption_problems
      end

      private

      def components = @sections.flat_map { |section| section.components.map { |component| [ section, component ] } }

      def raw_allowed = Array(@data["allowed"])

      def raw_exceptions = Array(@data["exceptions"])

      def allowed_ids = @allowed_ids ||= raw_allowed.filter_map { it["id"] if it.is_a?(Hash) }

      def filled?(value) = value.is_a?(String) && !value.strip.empty?

      def shape_problems
        return [ "#{@path} isn't a mapping with `allowed` and `exceptions`" ] unless @data.is_a?(Hash)
        return [ "#{@path} has no `allowed` list" ] unless @data.key?("allowed")

        allowed_shape + exception_shape
      end

      def allowed_shape
        bad = raw_allowed.each_with_index.reject { |entry, _| entry.is_a?(Hash) && filled?(entry["id"]) && filled?(entry["reason"]) }
          .map { |_, index| "#{@path}: allowed entry #{index + 1} needs an `id` and a `reason`" }
        bad + repeated(allowed_ids).map { "#{@path}: allowed id #{it} is listed twice" }
      end

      def exception_shape
        bad = raw_exceptions.each_with_index.reject { |entry, _| well_formed_exception?(entry) }
          .map { |entry, index| "#{@path}: exception entry #{index + 1} (#{entry.is_a?(Hash) ? entry["gem"] : "not a mapping"}) #{exception_needs(entry)}" }
        bad + repeated(raw_exceptions.filter_map { it["gem"] if it.is_a?(Hash) }).map { "#{@path}: the exception for gem #{it} is listed twice" }
      end

      def well_formed_exception?(entry)
        entry.is_a?(Hash) && filled?(entry["gem"]) && filled?(entry["reason"]) &&
          entry["licences"].is_a?(Array) && entry["licences"].any? && entry["licences"].all? { filled?(it) } &&
          valid_all_required?(entry)
      end

      # `all_required` may be absent; given, it is exactly true or false (a string such as "true" would silently mean false).
      def valid_all_required?(entry) = !entry.key?("all_required") || [ true, false ].include?(entry["all_required"])

      def exception_needs(entry)
        needs = "needs a `gem`, `licences` (a list) and a `reason`"
        entry.is_a?(Hash) && !valid_all_required?(entry) ? "#{needs}; `all_required` must be true or false" : needs
      end

      def repeated(values) = values.tally.select { |_, count| count > 1 }.keys

      def judge_problems
        components.flat_map { |section, component| judge(section, component) }
      end

      # The sentence(s) for one component: none when it passes.
      def judge(section, component)
        ids = component.identifiers.uniq.sort
        return [ "#{label(section, component)} declares no licence; #{@path} can judge only a declared SPDX id (#{DECISION})" ] if ids.empty?

        exemption = exemption_for(section, component)
        return [] if exemption && ids == exemption.licences

        allowed?(ids, strict: exemption&.all_required) ? [] : [ disallowed(section, component, ids, strict: exemption&.all_required) ]
      end

      def exemptions
        @exemptions ||= raw_exceptions.map do |entry|
          Exemption.new(gem: entry["gem"], licences: entry["licences"].uniq.sort, all_required: entry["all_required"] == true)
        end
      end

      def exemption_for(section, component)
        exemptions.find { it.gem == component.name } if section.key == :gems
      end

      def allowed?(ids, strict:)
        strict ? ids.all? { allowed_ids.include?(it) } : ids.any? { allowed_ids.include?(it) }
      end

      def label(section, component)
        section.key == :gems ? "gem #{component.name} #{component.version}" : "#{section.title} entry #{component.name.inspect} (#{component.version})"
      end

      def disallowed(section, component, ids, strict: false)
        way_out = section.key == :gems ? "allow the licence there, or list the gem under `exceptions` with its reason" : "allow the licence there, or drop the dependency"
        if strict
          "#{label(section, component)} is under #{ids.join(", ")}, which includes #{(ids - allowed_ids).join(", ")}, off the allowed list in #{@path} " \
            "(every licence of this gem must be allowed): #{way_out} (#{DECISION})"
        else
          "#{label(section, component)} is under #{ids.join(", ")}, none of which is on the allowed list in #{@path}: #{way_out} (#{DECISION})"
        end
      end

      # The stale exceptions: for a gem the lockfile no longer names, one whose licences changed, or one the list now allows.
      def exemption_problems
        gems = @sections.find { it.key == :gems }&.components.to_a
        exemptions.flat_map do |exemption|
          component = gems.find { it.name == exemption.gem }
          if !@locked_names.include?(exemption.gem)
            [ "#{@path}: the exception for gem #{exemption.gem} is stale: the lockfile no longer names it (#{DECISION})" ]
          elsif component.nil?
            [] # in the lockfile and not installed (a run with a group left out): neither judged nor stale
          else
            stale_problem(exemption, component.identifiers.uniq.sort)
          end
        end
      end

      def stale_problem(exemption, ids)
        if ids != exemption.licences
          [ "#{@path}: the exception for gem #{exemption.gem} is stale: it declares #{ids.join(", ")} now and the exception covers #{exemption.licences.join(", ")}; review it (#{DECISION})" ]
        elsif allowed?(ids, strict: exemption.all_required)
          [ "#{@path}: the exception for gem #{exemption.gem} is stale: the gem is allowed without it (#{DECISION})" ]
        else
          []
        end
      end
    end
  end
end
