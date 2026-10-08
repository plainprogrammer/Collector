require "rails_helper"

RSpec.describe MTG::Scryfall::Source, type: :model do
  subject(:source) { described_class.new(env:, client: MTG::Scryfall::Client.new(sleeper: ->(_) { })) }

  let(:env) { {} }
  let(:dir) { Pathname(Dir.mktmpdir) }

  after { FileUtils.rm_rf(dir) }

  it "declares its extension models and hosts", :aggregate_failures do
    expect(described_class.entry_extension_model).to eq(MTG::Printing)
    expect(described_class.identity_extension_model).to eq(MTG::Card)
    expect(described_class::ALLOWED_HOSTS).to include("cards.scryfall.io")
  end

  describe "#reapply?" do
    it "asks once for a catalog whose printings have no artwork ids yet (spec 011 AC-2.3)", :aggregate_failures do
      expect(source.reapply?).to be(false) # an empty catalog applies anyway
      printing = create(:mtg_printing)
      expect(source.reapply?).to be(true)
      printing.update!(illustration_id: "art-1")
      expect(source.reapply?).to be(false)
    end
  end

  describe "#languages" do
    it "defaults to English" do
      expect(source.languages).to eq([ "en" ])
    end

    context "when COLLECTOR_MTG_LANGUAGES is set" do
      let(:env) { { "COLLECTOR_MTG_LANGUAGES" => " JA, de " } }

      it "adds the configured languages, lower-cased and sorted" do
        expect(source.languages).to eq(%w[de en ja])
      end
    end

    context "when a code is not a Scryfall language" do
      let(:env) { { "COLLECTOR_MTG_LANGUAGES" => "ja,xx" } }

      it "raises a configuration error naming the code" do
        expect { source.languages }.to raise_error(Catalog::Sources::ConfigurationError, /xx/)
      end
    end
  end

  describe "#current_version and #download" do
    it "uses default_cards for English only and names the version after the file", :aggregate_failures do
      stub_scryfall(cards: [ scryfall_card ], type: "default_cards", stamp: "20260929090555")

      version = source.current_version(languages: [ "en" ])
      path = source.download(version, dir:)

      expect(version).to eq("default-cards-20260929090555")
      expect(path).to eq(dir.join("default-cards-20260929090555.jsonl.gz"))
      expect(path).to exist
    end

    it "uses all_cards when other languages are configured" do
      stub_scryfall(cards: [], type: "all_cards", stamp: "20260929091807")

      expect(source.current_version(languages: %w[en ja])).to eq("all-cards-20260929091807")
    end

    it "discards a download whose size differs from the published size", :aggregate_failures do
      stub_scryfall(cards: [ scryfall_card ], size: 1)
      version = source.current_version(languages: [ "en" ])

      expect { source.download(version, dir:) }.to raise_error(Catalog::Sources::IntegrityError, /published 1/)
      expect(dir.children).to be_empty
    end

    it "reuses a verified file and keeps only the two newest downloads", :aggregate_failures do
      %w[a b c].each_with_index do |name, index|
        dir.join("#{name}.jsonl.gz").write("x")
        FileUtils.touch(dir.join("#{name}.jsonl.gz"), mtime: Time.now - (10 - index))
      end
      stub_scryfall(cards: [ scryfall_card ])
      version = source.current_version(languages: [ "en" ])

      2.times { source.download(version, dir:) }

      expect(WebMock).to have_requested(:get, /data\.scryfall\.io/).once
      expect(dir.children.map { |path| path.basename.to_s }).to contain_exactly("c.jsonl.gz", "#{version}.jsonl.gz")
    end
  end

  describe "#each_entry" do
    it "yields records for configured paper languages and Malformed for bad lines", :aggregate_failures do
      path = dir.join("f.jsonl.gz")
      path.binwrite(gzip_jsonl([
        scryfall_card("id" => "en-1"),
        scryfall_card("id" => "ja-1", "lang" => "ja", "printed_name" => "稲妻"),
        scryfall_card("id" => "de-1", "lang" => "de"),
        scryfall_card("id" => "arena-1", "digital" => true, "games" => [ "arena" ]),
        scryfall_card("id" => "bad-1").except("collector_number"),
        "{not json"
      ]))

      yielded = []
      source.each_entry(path, languages: %w[en ja]) { |record| yielded << record }

      expect(yielded.grep(Catalog::Sources::EntryRecord).map(&:external_key)).to eq(%w[en-1 ja-1])
      expect(yielded.grep(Catalog::Sources::Malformed).map(&:external_key)).to eq([ "bad-1", nil ])
    end
  end

  describe "#each_set" do
    it "yields a record per set" do
      stub_scryfall(cards: [], sets: [ scryfall_set, scryfall_set("code" => "neo", "name" => "Kamigawa") ])

      expect(source.enum_for(:each_set).map(&:code)).to eq(%w[m10 neo])
    end
  end

  describe "#after_refresh and .status_lines (spec 011 AC-3.1, AC-3.11)" do
    it "hands an applied run to art matching, and reports its status", :aggregate_failures, :art_matching do
      run = build(:catalog_refresh_run, collectible_type: "mtg", status: "applied", source_version: "default-cards-1")
      expect { source.after_refresh(run) }.to have_enqueued_job(MTG::Art::BuildJob)
      expect(described_class.status_lines).to eq([ MTG::Art.status_line ])
    end
  end
end
