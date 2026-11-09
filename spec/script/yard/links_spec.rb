require "rails_helper"
require "tmpdir"
require Rails.root.join("script/yard/links").to_s

# The extension that makes the links of YARD's Markdown pages work (spec 054 FR-3, decision 6). The pure rewriting is
# here; spec/script/yard/site_spec.rb runs it inside a real YARD run.
RSpec.describe YardLinks::Rewriter, type: :model do # rubocop:disable RSpec/SpecFilePathFormat -- the file is script/yard/links.rb; Rewriter is its part that needs no YARD
  let(:root) { Pathname(Dir.mktmpdir) }
  let(:pages) { { "docs/architecture/a.md" => "a", "docs/adr/0001-x.md" => "0001-x" } }
  let(:warnings) { [] }
  let(:rewriter) { described_class.new(root:, pages:, warn: ->(message) { warnings << message }) }

  before do
    { "docs/architecture/a.md" => "# A\n\n## Option A: The `VACUUM INTO` step\n\n```\n# Not a heading\n```\n",
      "docs/adr/0001-x.md" => "# 0001\n\n## Consequences\n",
      "docs/releasing.md" => "# Releasing\n\n## What each trigger publishes\n",
      "docs/design-system/README.md" => "# DS\n" }.each do |path, body|
      root.join(path).dirname.mkpath
      root.join(path).write(body)
    end
  end

  after { FileUtils.remove_entry(root) }

  def rewrite(target, from: "docs/architecture/a.md") = rewriter.rewrite("See [x](#{target}).", from:)

  it "maps a link to another page of the site to its page, with a fragment mapped to YARD's heading id (AC-1.5)", :aggregate_failures do
    expect(rewrite("../adr/0001-x.md")).to eq("See [x](file.0001-x.html).")
    expect(rewrite("../adr/0001-x.md#consequences")).to eq("See [x](file.0001-x.html#Consequences).")
    expect(rewrite("../architecture/a.md#option-a-the-vacuum-into-step", from: "docs/adr/0001-x.md")).to eq("See [x](file.a.html#Option_A__The__VACUUM_INTO__step).")
  end

  it "sends a link to anything else to GitHub's main branch, keeping its fragment (AC-1.6)", :aggregate_failures do
    expect(rewrite("../releasing.md#what-each-trigger-publishes"))
      .to eq("See [x](https://github.com/plainprogrammer/Collector/blob/main/docs/releasing.md#what-each-trigger-publishes).")
    expect(rewrite("../design-system/")).to eq("See [x](https://github.com/plainprogrammer/Collector/tree/main/docs/design-system).")
  end

  it "leaves absolute URLs and in-page anchors alone", :aggregate_failures do
    expect(rewrite("https://example.com/a.md")).to eq("See [x](https://example.com/a.md).")
    expect(rewrite("#glossary")).to eq("See [x](#glossary).")
    expect(warnings).to be_empty
  end

  it "warns about a link to a file that doesn't exist and leaves it as written (AC-2.7)", :aggregate_failures do
    expect(rewrite("missing.md")).to eq("See [x](missing.md).")
    expect(rewrite("../../../outside.md")).to eq("See [x](../../../outside.md).")
    expect(warnings.size).to eq(2)
    expect(warnings.first).to include("docs/architecture/a.md", "missing.md", "doesn't exist")
  end

  it "passes a fragment that names no heading through unchanged, without a warning", :aggregate_failures do
    expect(rewrite("../adr/0001-x.md#nope")).to eq("See [x](file.0001-x.html#nope).")
    expect(warnings).to be_empty
  end

  it "doesn't touch a link inside a fenced code block", :aggregate_failures do
    text = "```\n[x](missing.md)\n```\n"

    expect(rewriter.rewrite(text, from: "docs/architecture/a.md")).to eq(text)
    expect(warnings).to be_empty
  end

  it "does not count a '#' line in a fenced block as a heading" do
    expect(rewrite("a.md#not-a-heading")).to eq("See [x](file.a.html#not-a-heading).")
  end

  describe ".slug and .yard_id" do
    it "give GitHub's anchor and YARD's id of a heading", :aggregate_failures do
      expect(YardLinks.slug("Option A: The `VACUUM INTO` step")).to eq("option-a-the-vacuum-into-step")
      expect(YardLinks.yard_id("Option A: The `VACUUM INTO` step")).to eq("Option_A__The__VACUUM_INTO__step")
      expect(YardLinks.yard_id("A workflow run (`ci.yml`)")).to eq("A_workflow_run___ci_yml__")
    end
  end
end
