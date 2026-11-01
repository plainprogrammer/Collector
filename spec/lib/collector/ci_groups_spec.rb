require "rails_helper"
require Rails.root.join("lib/collector/ci_groups").to_s

RSpec.describe Collector::CiGroups do
  describe ".parse" do
    it "selects every step without an argument (decision 4)" do
      expect(described_class.parse([])).to have_attributes(group: :all, index: nil, total: nil)
    end

    it "selects the checks without RSpec (decision 4)" do
      expect(described_class.parse([ "checks" ])).to have_attributes(group: :checks, index: nil, total: nil)
    end

    it "selects the whole suite, with no shard (decision 4)" do
      expect(described_class.parse([ "rspec" ])).to have_attributes(group: :rspec, index: nil, total: nil)
    end

    it "selects one shard of the suite (decision 4)" do
      expect(described_class.parse([ "rspec", "2/4" ])).to have_attributes(group: :rspec, index: 2, total: 4)
    end

    [ [ "rspec", "5/4" ], [ "rspec", "0/4" ], [ "rspec", "1/0" ], [ "rspec", "a/b" ],
      [ "lint" ], [ "checks", "1/2" ], [ "rspec", "1/2", "x" ] ].each do |argv|
      it "refuses #{argv.join(' ').inspect} and names the accepted forms (AC-1.6)", :aggregate_failures do
        expect { described_class.parse(argv) }.to raise_error(described_class::Unknown) do |error|
          expect(error.message).to include(*described_class::FORMS)
          expect(described_class::FORMS.size).to eq(4)
        end
      end
    end
  end
end
