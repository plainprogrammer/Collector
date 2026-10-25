require "rails_helper"
require Rails.root.join("script/upgrade/rules").to_s

RSpec.describe "Upgrade seeds", :upgrade do
  let(:seeds) { Rails.root.join("script/upgrade/seeds") }
  let(:database) { ActiveRecord::Base.lease_connection.raw_connection }

  def run_seed(name)
    original = $stdout
    $stdout = StringIO.new
    load seeds.join(name).to_s
    $stdout.string
  ensure
    $stdout = original
  end

  def summary(output) = JSON.parse(output.lines.grep(/\AUPGRADE-SEED-COMPLETE /).last.delete_prefix("UPGRADE-SEED-COMPLETE "))

  describe "next.rb, run on the code under test" do
    it "prints the completion line with what the harness reads (AC-2.2)", :aggregate_failures do
      facts = summary(run_seed("next.rb"))
      expect(facts.keys).to contain_exactly("release", "password", "marker", "locations", "users")
      expect(facts["users"].map { it["email"] }).to eq(%w[ada@upgrade.example grace@upgrade.example])
      expect(facts["users"].first["lots"]).to be >= 2000
      expect(facts["users"].first["names"].size).to eq(50)
      expect(facts["users"].last).to include("lots" => 0, "names" => [])
      expect(facts["locations"]).to eq([ "Binder A", "Shelf B" ])
    end

    it "fills every table db/schema.rb creates, except those listed under next (AC-2.6, FR-7)" do
      run_seed("next.rb")
      schema_tables = Rails.root.join("db/schema.rb").read.scan(/^  create_table "([^"]+)"/).flatten
      listed = Upgrade::SeedExceptions.load(seeds.join("../seed_exceptions.yml"), "next").entries
      problems, = Upgrade::SeedExceptions.coverage(database, listed, label: "next", seed: "script/upgrade/seeds/next.rb", only: schema_tables)
      expect(problems).to be_empty
    end

    it "leaves what AC-2.3 asks for" do
      run_seed("next.rb")
      expect(Upgrade::Compare.seed_problems(database)).to be_empty
    end

    it "schedules a job with the marker argument a year ahead" do
      expect { run_seed("next.rb") }.to have_enqueued_job(Catalog::RefreshJob).with("mtg", "upgrade-marker")
    end
  end

  describe "both seeds' source" do
    it "parses, names no constant and prints one completion line", :aggregate_failures do
      %w[0.2.1.rb next.rb].each do |name|
        source = seeds.join(name).read
        expect { RubyVM::InstructionSequence.compile(source) }.not_to raise_error
        expect(source).not_to match(/^\s*[A-Z][A-Za-z_]*\s*=[^=]/)
        expect(source.scan("UPGRADE-SEED-COMPLETE").size).to eq(1)
      end
    end
  end

  describe "0.2.1.rb" do
    it "uses nothing that arrived after v0.2.1" do
      expect(seeds.join("0.2.1.rb").read).not_to match(/\b(Location|NumberEntry|ImportUpload|ActiveStorage|Catalog::Operation)\b/)
    end
  end
end
