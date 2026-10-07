module CardScannerPhase3
  # The full fetch's cost before anything is fetched (spec 010 AC-1.2): the uncached artworks that have an image URL, at
  # spec 008's measured bytes and seconds per image. Nothing is fetched to make it.
  module Estimate
    module_function

    def call(artworks, cached:, size: "small", measured: SPEC008_FETCH)
      fetchable = artworks.select { |_, artwork| artwork[size] }
      remaining = fetchable.keys.reject { cached.call(it) }
      per_bytes = measured["bytes"].fdiv(measured["images"])
      per_seconds = measured["seconds"].fdiv(measured["images"])
      { "artworks" => artworks.size, "with_image_url" => fetchable.size, "cached" => fetchable.size - remaining.size, "to_fetch" => remaining.size,
        "per_image" => { "bytes" => per_bytes.round(1), "seconds" => per_seconds.round(4) }, "bytes" => (per_bytes * remaining.size).round,
        "hours" => (per_seconds * remaining.size / 3600).round(3),
        "basis" => "spec 008 research.md §7: #{measured["images"]} images, #{measured["bytes"]} bytes, #{measured["seconds"]} s" }
    end
  end
end
