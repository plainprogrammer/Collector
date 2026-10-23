require "rails_helper"

RSpec.describe Collector::Backup::FreeSpace, :backup do
  it "reads the bytes available on the filesystem that holds a path" do
    expect(described_class.bytes(Dir.tmpdir)).to be_a(Integer).and be_positive
  end

  it "answers nil when it can't read the figure, so the check is skipped rather than guessed" do
    expect(described_class.bytes("/no/such/place/for/collector")).to be_nil
  end
end
