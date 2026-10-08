require "open3"

# Decodes a cached artwork image to 8-bit RGB with ImageMagick's CLI (ADR 0011), the spikes' path, which agreed with
# the browser's canvas to 0 bits. `magick` (ImageMagick 7) is preferred; `convert` (ImageMagick 6) is accepted.
module MTG::Art::Decoder
  COMMANDS = %w[magick convert].freeze

  class Error < StandardError; end

  Image = Struct.new(:width, :height, :data) do
    def rgb(x, y)
      offset = (y * width + x) * 3
      [ data.getbyte(offset), data.getbyte(offset + 1), data.getbyte(offset + 2) ]
    end
  end

  def self.command
    @command ||= COMMANDS.find { |name| system(name, "-version", out: File::NULL, err: File::NULL) } ||
      raise(Error, "ImageMagick isn't installed: art matching needs the magick (or convert) command")
  end

  def self.decode(path)
    out, status = Open3.capture2(command, path.to_s, "-depth", "8", "ppm:-", binmode: true, err: File::NULL)
    raise Error, "ImageMagick couldn't decode #{File.basename(path.to_s)}" unless status.success?

    parse(out)
  end

  def self.parse(bytes)
    header = bytes.b.match(/\AP6\s+(\d+)\s+(\d+)\s+(\d+)\s/) or raise Error, "expected a binary 8-bit P6 image"
    raise Error, "expected 8-bit P6 (maxval 255)" unless header[3] == "255"

    width, height = header[1].to_i, header[2].to_i
    data = bytes.b.byteslice(header[0].bytesize, width * height * 3)
    raise Error, "short P6 data" unless data && data.bytesize == width * height * 3

    Image.new(width, height, data)
  end
end
