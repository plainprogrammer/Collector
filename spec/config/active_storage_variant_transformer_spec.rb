require "rails_helper"

# Active Storage variants use libvips through ruby-vips (spec 014, ADR 0013). No blobs or tables are involved.
RSpec.describe ActiveStorage, ".variant_transformer" do
  it "is the vips transformer (AC-2.2)" do
    expect(described_class.variant_transformer).to eq(ActiveStorage::Transformers::Vips)
  end

  it "resizes an image with libvips (AC-2.1)" do
    source = Tempfile.create([ "variant", ".png" ], binmode: true)
    source.write(png_bytes(40, 20) { [ 200, 100, 50 ] })
    source.rewind
    size = nil
    # The transformer deletes its output when the block returns, so measure it inside.
    described_class.variant_transformer.new(resize_to_limit: [ 10, 10 ]).transform(source, format: "png") do |output|
      image = Vips::Image.new_from_file(output.path)
      size = [ image.width, image.height ]
    end
    expect(size).to eq([ 10, 5 ])
  ensure
    source&.close
    File.unlink(source.path) if source
  end

  it "comes from a ruby-vips that Bundler.require doesn't load, so the app boots without libvips (AC-3.3)" do
    dependency = Bundler.definition.dependencies.find { |candidate| candidate.name == "ruby-vips" }
    expect(dependency&.autorequire).to eq([])
  end
end
