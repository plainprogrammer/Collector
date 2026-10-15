require "rails_helper"
require "puma"
require "puma/configuration"
require "yaml"

# Spec 025 decision 6: every layer that receives a request body refuses one over 40 MB before keeping it, so an
# upload never fills the disk. An export file is at most 32 MB (CollectionImport::MAX_BYTES).
RSpec.describe "The request body limit" do
  let(:limit) { 40_000_000 }

  it "is above the largest file the import preview reads" do
    expect(limit).to be > CollectionImport::MAX_BYTES
  end

  it "is set in Puma, which every environment runs" do
    options = Puma::Configuration.new(config_files: [ Rails.root.join("config/puma.rb").to_s ]).load

    expect(options[:http_content_length_limit]).to eq(limit)
  end

  it "is set for Thruster in the published image" do
    expect(Rails.root.join("Dockerfile").readlines(chomp: true).map(&:strip)).to include(%(ENV MAX_REQUEST_BODY="#{limit}"))
  end

  it "is set for kamal-proxy, which otherwise buffers up to 1 GB to disk" do
    expect(YAML.load_file(Rails.root.join("config/deploy.yml")).dig("proxy", "buffering", "max_request_body")).to eq(limit)
  end
end
