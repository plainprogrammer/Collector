# The art fingerprint (ADR 0006), the same arithmetic and loop order as the scanner page's scanner/art.js: the art box
# (x 14–86%, y 16–50% of the card) area-resampled to 17×16, four planes (grey, blue, green, red), each a difference hash
# of horizontal neighbours, most significant bit first: 1,024 bits as 128 bytes. The index stores the zero offset.
module MTG::Art::Fingerprint
  ZERO = { "dx" => 0, "dy" => 0 }.freeze
  POPCOUNT = Array.new(65_536) { it.to_s(2).count("1") }.freeze

  module_function

  def of(image, offset = ZERO, settings: MTG::Art::Settings.fingerprint)
    cols, rows = settings.fetch("grid")
    x0, y0, x1, y1 = box(image.width, image.height, settings.fetch("box"), offset)
    r, g, b = area_resample(image, x0, y0, x1, y1, cols, rows)
    grey = r.each_index.map { 0.299 * r[it] + 0.587 * g[it] + 0.114 * b[it] }
    [ grey, b, g, r ].map { dhash(it, cols, rows) }.join
  end

  # The crop box in pixels for an offset: dx/dy shift by a share of the card, inset shrinks every side.
  def box(width, height, box, offset)
    inset = offset["inset"].to_f
    bw, bh = box["x1"] - box["x0"], box["y1"] - box["y0"]
    [ (box["x0"] + offset["dx"].to_f + inset * bw) * width, (box["y0"] + offset["dy"].to_f + inset * bh) * height,
      (box["x1"] + offset["dx"].to_f - inset * bw) * width, (box["y1"] + offset["dy"].to_f - inset * bh) * height ]
  end

  # Each output cell averages the source pixels it overlaps, weighted by the overlap.
  def area_resample(image, x0, y0, x1, y1, cols, rows)
    cell_w, cell_h = (x1 - x0) / cols, (y1 - y0) / rows
    r, g, b = Array.new(cols * rows, 0.0), Array.new(cols * rows, 0.0), Array.new(cols * rows, 0.0)
    rows.times do |j|
      cy0, cy1 = y0 + j * cell_h, y0 + (j + 1) * cell_h
      cols.times do |i|
        cx0, cx1 = x0 + i * cell_w, x0 + (i + 1) * cell_w
        k = j * cols + i
        r[k], g[k], b[k] = cell(image, cx0, cy0, cx1, cy1)
      end
    end
    [ r, g, b ]
  end

  def cell(image, cx0, cy0, cx1, cy1)
    sr = sg = sb = weight = 0.0
    (cy0.floor.clamp(0, image.height - 1)..(cy1.ceil - 1).clamp(0, image.height - 1)).each do |py|
      wy = [ cy1, py + 1 ].min - [ cy0, py ].max
      next if wy <= 0

      (cx0.floor.clamp(0, image.width - 1)..(cx1.ceil - 1).clamp(0, image.width - 1)).each do |px|
        wx = [ cx1, px + 1 ].min - [ cx0, px ].max
        next if wx <= 0

        w = wx * wy
        pr, pg, pb = image.rgb(px, py)
        sr += pr * w
        sg += pg * w
        sb += pb * w
        weight += w
      end
    end
    [ sr / weight, sg / weight, sb / weight ]
  end

  def dhash(plane, cols, rows)
    bits = +""
    rows.times { |j| (cols - 1).times { |i| bits << (plane[j * cols + i + 1] > plane[j * cols + i] ? "1" : "0") } }
    [ bits ].pack("B*")
  end

  # Bits that differ between two fingerprints (agreement checks; the search itself runs on the page).
  def hamming(a, b)
    words_a, words_b = a.unpack("n*"), b.unpack("n*")
    words_a.each_index.sum { POPCOUNT[words_a[it] ^ words_b[it]] }
  end
end
