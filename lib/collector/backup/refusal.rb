module Collector
  module Backup
    # A command that stops before it changes anything, with what is wrong and what to do about it: two plain sentences
    # an operator can act on, never an exception class or a backtrace (FR-4, AC-3.8).
    class Refusal < StandardError
      attr_reader :problem, :advice

      def initialize(problem, advice)
        @problem = problem
        @advice = advice
        super("#{problem} #{advice}")
      end
    end
  end
end
