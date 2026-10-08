# A lossless, opaque PNG with no colour profile or gamma chunk, so ImageMagick and the browser see the same pixels
# (spec 011 AC-8.3). The block gives each pixel's [r, g, b].
module PngHelpers
  def png_bytes(width, height)
    rows = (0...height).map { |y| "\x00".b + (0...width).map { |x| yield(x, y).pack("C3") }.join }.join
    chunk = ->(type, data) { [ data.bytesize ].pack("N") + type.b + data + [ Zlib.crc32(type.b + data) ].pack("N") }
    "\x89PNG\r\n\x1A\n".b + chunk.("IHDR", [ width, height, 8, 2, 0, 0, 0 ].pack("NNC5")) +
      chunk.("IDAT", Zlib::Deflate.deflate(rows)) + chunk.("IEND", "".b)
  end

  # A deterministic noisy picture the size of a Scryfall small image, so every fingerprint bit is exercised.
  def noisy_png(width: 146, height: 204, seed: 7)
    state = seed
    png_bytes(width, height) { Array.new(3) { state = (state * 16_807) % 2_147_483_647; state % 256 } }
  end
end

RSpec.configure { |config| config.include PngHelpers }
