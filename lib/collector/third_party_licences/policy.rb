module Collector
  class ThirdPartyLicences
    # Judges the components of {ThirdPartyLicences.build}'s sections against the allowed list and the named exceptions in
    # `config/licence_policy.yml` (spec 091), as a list of problems each naming its offender, the licence and the file.
    #
    # Every input is injected, so a spec shows each rule failing on a small fixture; `for_repository` (T1.3) builds the real ones
    # and the `licences:check` task prints the problems. A component passes if any one of its identifiers is allowed (spec 091
    # decision 2); one with none, or with a string that is not exactly an allowed id, fails (decision 5). Nothing here reads
    # a gem or a licence file: the one reader is {ThirdPartyLicences} (no second reader of the bundle).
    #
    # @see file:catalog-core.md
    # @see file:0031-a-dependency-licence-is-a-decision.md
    class Policy
      # The policy file, relative to `Rails.root`.
      PATH = "config/licence_policy.yml".freeze

      # The decision the failure message points at.
      DECISION = "ADR 0031".freeze

      # A named exception, as the rules use it: the `gem`, its `licences` (sorted, a set) and whether its list is `all_required`.
      # Its `reason` is for the reader of the file; no rule reads it.
      Exemption = Data.define(:gem, :licences, :all_required)

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
      # malformed list would blame every gem.
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

        allowed_shape + exception_shape
      end

      def allowed_shape
        bad = raw_allowed.each_with_index.reject { |entry, _| entry.is_a?(Hash) && filled?(entry["id"]) && filled?(entry["reason"]) }
          .map { |_, index| "#{@path}: allowed entry #{index + 1} needs an `id` and a `reason`" }
        bad + repeated(allowed_ids).map { "#{@path}: allowed id #{it} is listed twice" }
      end

      def exception_shape
        bad = raw_exceptions.each_with_index.reject { |entry, _| well_formed_exception?(entry) }
          .map { |entry, index| "#{@path}: exception entry #{index + 1} (#{entry.is_a?(Hash) ? entry["gem"] : "not a mapping"}) needs a `gem`, `licences` (a list) and a `reason`" }
        bad + repeated(raw_exceptions.filter_map { it["gem"] if it.is_a?(Hash) }).map { "#{@path}: the exception for gem #{it} is listed twice" }
      end

      def well_formed_exception?(entry)
        entry.is_a?(Hash) && filled?(entry["gem"]) && filled?(entry["reason"]) &&
          entry["licences"].is_a?(Array) && entry["licences"].any? && entry["licences"].all? { filled?(it) }
      end

      def repeated(values) = values.tally.select { |_, count| count > 1 }.keys

      def judge_problems
        components.flat_map { |section, component| judge(section, component) }
      end

      # The sentence(s) for one component: none when it passes.
      def judge(section, component)
        ids = component.identifiers.uniq.sort
        return [ "#{label(section, component)} declares no licence; #{@path} can judge only a declared SPDX id (#{DECISION})" ] if ids.empty?

        allowed?(ids, strict: false) ? [] : [ disallowed(section, component, ids) ]
      end

      def allowed?(ids, strict:)
        strict ? ids.all? { allowed_ids.include?(it) } : ids.any? { allowed_ids.include?(it) }
      end

      def label(section, component)
        section.key == :gems ? "gem #{component.name} #{component.version}" : "#{section.title} entry #{component.name.inspect} (#{component.version})"
      end

      def disallowed(section, component, ids)
        way_out = section.key == :gems ? "allow the licence there, or list the gem under `exceptions` with its reason" : "allow the licence there, or drop the dependency"
        "#{label(section, component)} is under #{ids.join(", ")}, none of which is on the allowed list in #{@path}: #{way_out} (#{DECISION})"
      end

      # T1.2 fills this in; until then there is none.
      def exemption_problems = []
    end
  end
end
