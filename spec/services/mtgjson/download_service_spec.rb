# frozen_string_literal: true

require "rails_helper"

RSpec.describe MTGJSON::DownloadService do
  describe "#call" do
    let(:service) { described_class.new }
    let(:test_file_path) { Rails.root.join("tmp/test_mtgjson.sqlite") }

    before do
      FileUtils.rm_f(test_file_path)
    end

    after do
      FileUtils.rm_f(test_file_path)
    end

    context "with local file path" do
      it "copies file to destination" do
        source = Rails.root.join("spec/fixtures/mtgjson_sample.sqlite")
        FileUtils.mkdir_p(File.dirname(source))
        FileUtils.touch(source)

        result = service.call(source: source.to_s, destination: test_file_path.to_s)

        expect(result[:success]).to be true
        expect(File.exist?(test_file_path)).to be true
      end

      it "returns error if source file does not exist" do
        result = service.call(source: "/nonexistent/file.sqlite", destination: test_file_path.to_s)

        expect(result[:success]).to be false
        expect(result[:error]).to include("Source file not found")
      end
    end

    context "with URL download" do
      it "downloads file from URL" do
        url = "https://example.com/AllPrintings.sqlite"
        stub_request(:get, url).to_return(body: "test data", status: 200)

        result = service.call(source: url, destination: test_file_path.to_s)

        expect(result[:success]).to be true
        expect(File.exist?(test_file_path)).to be true
      end

      it "returns error on download failure" do
        url = "https://example.com/AllPrintings.sqlite"
        stub_request(:get, url).to_return(status: 404)

        result = service.call(source: url, destination: test_file_path.to_s)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end

    context "with default MTGJSON URL" do
      it "uses default MTGJSON URL when no source provided" do
        default_url = "https://mtgjson.com/api/v5/AllPrintings.sqlite"
        stub_request(:get, default_url).to_return(body: "mtgjson data", status: 200)

        result = service.call(destination: test_file_path.to_s)

        expect(result[:success]).to be true
        expect(File.exist?(test_file_path)).to be true
      end
    end
  end
end
