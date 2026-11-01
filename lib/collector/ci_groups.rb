# The groups bin/ci runs (spec 035 decision 4): all steps, the checks without RSpec, the whole suite, or one shard.
# Development tooling, required by path; not autoloaded and not in the image.
module Collector
  module CiGroups
    Unknown = Class.new(ArgumentError)
    Selection = Data.define(:group, :index, :total)
    FORMS = [ "bin/ci", "bin/ci checks", "bin/ci rspec", "bin/ci rspec N/M (1 <= N <= M)" ].freeze

    def self.parse(argv)
      case argv
      in [] then Selection.new(:all, nil, nil)
      in [ "checks" ] then Selection.new(:checks, nil, nil)
      in [ "rspec" ] then Selection.new(:rspec, nil, nil)
      in [ "rspec", %r{\A([1-9]\d*)/([1-9]\d*)\z} ] if $1.to_i <= $2.to_i then Selection.new(:rspec, $1.to_i, $2.to_i)
      else raise Unknown, "Unknown CI group #{argv.join(' ').inspect}. Accepted: #{FORMS.join(', ')}"
      end
    end
  end
end
