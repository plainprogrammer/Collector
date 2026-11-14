module Collector
  class ThirdPartyLicences
    # Everything the `licences:check` step reports: spec 087's guard (the manifest, the pins and the bundle agree) and the
    # policy (every component is under an allowed licence), in one list, so a pull request that adds an importmap pin with
    # no entry fails `bin/ci checks` as well as the suite (spec 091 decision 7).
    #
    # @see file:catalog-core.md
    class Check
      # The check of this repository: the real guard and the real policy.
      #
      # Reads the manifest, every licence file and the lockfile; needs the application booted (the importmap).
      #
      # @param policy_path [String, Pathname] the policy file; default `config/licence_policy.yml`
      # @return [Check]
      # @raise [SystemCallError] when the policy or the manifest can't be read
      # @raise [Psych::Exception] when either isn't plain YAML
      def self.for_repository(policy_path: Rails.root.join(Policy::PATH))
        new(audit: Audit.for_repository, policy: Policy.for_repository(policy_path:))
      end

      # @param audit [#problems] spec 087's guard, or a stand-in
      # @param policy [#problems, #component_count] the policy, or a stand-in
      def initialize(audit:, policy:)
        @audit = audit
        @policy = policy
      end

      # The guard's problems, then the policy's.
      #
      # @return [Array<String>] empty when both agree
      def problems = @audit.problems + @policy.problems

      # How many components the policy judged.
      #
      # @return [Integer]
      def component_count = @policy.component_count
    end
  end
end
