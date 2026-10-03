module CardScannerPhase2
  # Raw 8-bit RGB pixels from `magick <file> -depth 8 ppm:-`, the only decoding step outside pure Ruby.
  module Ppm
    Image = Struct.new(:width, :height, :data) do
      def rgb(x, y)
        offset = (y * width + x) * 3
        [ data.getbyte(offset), data.getbyte(offset + 1), data.getbyte(offset + 2) ]
      end
    end

    module_function

    def parse(bytes)
      header = bytes.b.match(/\AP6\s+(\d+)\s+(\d+)\s+(\d+)\s/) or raise ArgumentError, "expected a binary 8-bit P6 image"
      raise ArgumentError, "expected 8-bit P6 (maxval 255)" unless header[3] == "255"

      width, height = header[1].to_i, header[2].to_i
      data = bytes.b.byteslice(header[0].bytesize, width * height * 3)
      raise ArgumentError, "short P6 data" unless data.bytesize == width * height * 3

      Image.new(width, height, data)
    end

    def decode(path, magick: "magick")
      out = IO.popen([ magick, path.to_s, "-depth", "8", "ppm:-" ], "rb", &:read)
      raise ArgumentError, "#{magick} failed on #{path}" unless $?.success?

      parse(out)
    end
  end
end
