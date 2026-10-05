require "rails_helper"

RSpec.describe MTG::CollectorNumber, type: :model do
  describe ".one_digit_apart?" do
    {
      [ "117", "17" ] => true, [ "282", "202" ] => true, [ "51", "5" ] => true, [ "0117", "17" ] => true,
      [ "117a", "17a" ] => true, [ "52★", "5★" ] => true,
      [ "117", "117" ] => false, [ "117", "1" ] => false, [ "117a", "17" ] => false, [ "117", "17a" ] => false,
      [ "117", nil ] => false, [ "", "1" ] => false
    }.each do |(printed, read), expected|
      it "is #{expected} for #{printed.inspect} printed and #{read.inspect} read (AC-5.3)" do
        expect(described_class.one_digit_apart?(printed, read)).to be(expected)
      end
    end
  end
end
