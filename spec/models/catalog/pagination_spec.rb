require "rails_helper"

# What counts as a page number: only decimal digits, so `010` is page 10 and every other spelling
# shows page 1 (#204 ruling 2; spec 002 AC-1.14).
RSpec.describe Catalog::Pagination, type: :model do
  def page_for(requested, total_count: 250, per_page: 10)
    described_class.for(total_count:, requested_page: requested, per_page:).page
  end

  describe ".for" do
    it "reads a positive decimal integer as that page", :aggregate_failures do
      expect(page_for("7")).to eq(7)
      expect(page_for(7)).to eq(7)
      expect(page_for("25")).to eq(25)
    end

    it "reads leading zeros as decimal, not octal", :aggregate_failures do
      expect(page_for("010")).to eq(10)
      expect(page_for("08")).to eq(8)
      expect(page_for("0007")).to eq(7)
    end

    it "shows page 1 for anything that isn't a positive decimal integer", :aggregate_failures do
      [ "0x10", "0b11", "0o7", "1_0", "-1", "+5", "0", "00", "", " ", " 7", "7 ", "1.5", "1e1", "abc", "٣", "[\"4\"]" ].each do |requested|
        expect(page_for(requested)).to eq(1), "expected #{requested.inspect} to show page 1"
      end
      expect(page_for(nil)).to eq(1)
      expect(page_for(-3)).to eq(1)
      expect(page_for([ "4" ])).to eq(1)
    end

    it "clamps a page past the end to the last page", :aggregate_failures do
      expect(page_for("99")).to eq(25)
      expect(page_for("99999999999999999999999")).to eq(25)
      expect(page_for("026")).to eq(25)
    end

    it "has one page when there is nothing to list", :aggregate_failures do
      expect(page_for("3", total_count: 0)).to eq(1)
      expect(described_class.for(total_count: 0, requested_page: "3", per_page: 10).total_pages).to eq(1)
    end
  end
end
