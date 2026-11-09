require "rails_helper"
require "open3"
require "tmpdir"

# A real `yard doc` over a small fixture with the extension loaded (spec 054 FR-3: AC-1.5, AC-1.6, AC-1.7, AC-2.7, AC-1.9).
# Slower than the unit examples (about 3 s), so it holds the end-to-end checks: that the hook is reached, that a mapped
# fragment is an id the target page has, and that a dead link fails the run.
RSpec.describe "The extension in a YARD run", type: :model do
  let(:fixture) { Rails.root.join("spec/fixtures/yard_site") }
  let(:extension) { Rails.root.join("script/yard/links.rb").to_s }

  def yard(*args, out:)
    Open3.capture3(Rails.root.join("bin/yard").to_s, "doc", "--no-save", "--fail-on-warning", "--markup", "markdown",
                   "--output-dir", out, "--load", extension, "--files", "docs/*.md", "lib/**/*.rb", *args, chdir: fixture.to_s)
  end

  def page(out, name) = File.read(File.join(out, "file.#{name}.html"))

  it "links the pages to each other, at ids the target has, and the rest to GitHub", :aggregate_failures do
    Dir.mktmpdir do |out|
      stdout, stderr, status = yard(out:)

      expect(status).to be_success, stdout + stderr
      alpha = page(out, "alpha")
      beta = page(out, "beta")
      expect(alpha).to include('href="file.beta.html#What_it_keeps"')
      expect(beta).to include('id="What_it_keeps"')
      expect(beta).to include('href="file.alpha.html#Option_A__The__VACUUM_INTO__step"')
      expect(alpha).to include('id="Option_A__The__VACUUM_INTO__step"')
      expect(alpha).to include('href="https://github.com/plainprogrammer/Collector/blob/main/notes/outside.md#what-each-trigger-publishes"')
      expect(alpha).to include('href="https://example.com/page"')
    end
  end

  it "renders a class comment's @see file: as a link to the page, with no warning (AC-1.9)", :aggregate_failures do
    Dir.mktmpdir do |out|
      stdout, stderr, status = yard(out:)

      expect(status).to be_success, stdout + stderr
      expect(File.read(File.join(out, "Thing.html"))).to include('href="file.alpha.html"')
    end
  end

  it "leaves the documents on disk as they were (AC-1.7)" do
    Dir.mktmpdir do |out|
      before = Dir[fixture.join("docs/*.md")].to_h { [ it, File.read(it) ] }
      yard(out:)

      expect(Dir[fixture.join("docs/*.md")].to_h { [ it, File.read(it) ] }).to eq(before)
    end
  end

  it "fails the run, naming the page and the link, when a link points at a missing file (AC-2.7)", :aggregate_failures do
    Dir.mktmpdir do |dir|
      docs = Pathname(dir).join("docs")
      docs.mkpath
      docs.join("bad.md").write("# Bad\n\nSee [nothing](missing.md).\n")
      stdout, stderr, status = Open3.capture3(Rails.root.join("bin/yard").to_s, "doc", "--no-save", "--fail-on-warning",
                                              "--markup", "markdown", "--output-dir", Pathname(dir).join("out").to_s,
                                              "--load", extension, "--files", "docs/*.md", chdir: dir)

      expect(status).not_to be_success
      expect(stdout + stderr).to include("docs/bad.md", "missing.md", "doesn't exist")
    end
  end
end
