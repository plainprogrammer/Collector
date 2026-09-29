require "rails_helper"
require "tmpdir"

RSpec.describe Collector::DevPort do
  let(:dir) { Dir.mktmpdir }
  let(:main_checkout) { File.join(dir, "main").tap { |p| FileUtils.mkdir_p(File.join(p, ".git")) } }
  let(:linked_worktree) do
    File.join(dir, "wt").tap do |p|
      FileUtils.mkdir_p(p)
      File.write(File.join(p, ".git"), "gitdir: /x\n")
    end
  end
  let(:dev) { { "RAILS_ENV" => "development" } }

  after { FileUtils.remove_entry(dir) }

  describe ".resolve" do
    it "uses 3000 in the main checkout" do
      expect(described_class.resolve(root: main_checkout, env: dev)).to eq(3000)
    end

    it "derives a stable port in 3001..3999 in a linked worktree", :aggregate_failures do
      port = described_class.resolve(root: linked_worktree, env: dev)
      expect(port).to be_between(3001, 3999)
      expect(described_class.resolve(root: linked_worktree, env: dev)).to eq(port)
      expect(port).to eq(described_class.for_worktree(File.realpath(linked_worktree)))
    end

    it "defaults to development when RAILS_ENV is unset" do
      expect(described_class.resolve(root: linked_worktree, env: {})).not_to eq(3000)
    end

    it "honours PORT everywhere", :aggregate_failures do
      expect(described_class.resolve(root: linked_worktree, env: dev.merge("PORT" => "4567"))).to eq(4567)
      expect(described_class.resolve(root: main_checkout, env: { "RAILS_ENV" => "production", "PORT" => "8080" })).to eq(8080)
    end

    it "uses 3000 outside development or without git metadata", :aggregate_failures do
      expect(described_class.resolve(root: linked_worktree, env: { "RAILS_ENV" => "production" })).to eq(3000)
      expect(described_class.resolve(root: linked_worktree, env: { "RAILS_ENV" => "test" })).to eq(3000)
      expect(described_class.resolve(root: dir, env: dev)).to eq(3000)
    end
  end

  describe ".for_worktree" do
    let(:paths) { %w[/home/a/Collector/wt-1 /home/a/Collector/wt-2 /srv/orca/Collector/feature /tmp/x] }

    it "is a pure, in-range function of the path", :aggregate_failures do
      ports = paths.map { |p| described_class.for_worktree(p) }
      expect(ports).to all(be_between(3001, 3999))
      expect(paths.map { |p| described_class.for_worktree(p) }).to eq(ports)
      expect(ports.uniq.size).to eq(paths.size)
    end
  end
end
