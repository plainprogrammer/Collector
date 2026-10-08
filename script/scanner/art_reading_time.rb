# Spec 011 NFR Performance: the reading request's ranking time on the server with and without the art evidence, over the
# measured sitting's readings (development measurement mode). Not gating. Medians are conventional (the mean of the
# middle two for an even count). bin/rails runner script/scanner/art_reading_time.rb
# Ruby 4 no longer ships benchmark as a default gem; a monotonic clock is all this needs.
seconds = lambda do |&block|
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  block.call
  Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
end

run = Scanner::MeasurementRun.current or abort("Measurement mode is off; run this in development.")
readings = run.readings.index_by { it["reading_key"] }
pairs = run.measured_captures.filter_map do |capture|
  sent = readings.dig(capture["reading_key"], "artworks") or next
  artworks = sent.map { MTG::Art::Sent::Artwork.new(id: it["id"], distance: it["distance"]) }
  text = { name_text: capture["name_text"].to_s, collector_text: capture["collector_text"].to_s }
  [ seconds.call { MTG::Reading.new(**text).resolve.candidates.to_a },
    seconds.call { MTG::Reading.new(**text, artworks:).resolve.candidates.to_a } ]
end
abort "No measured readings with artworks." if pairs.empty?
median = lambda do |values|
  sorted = values.sort
  middle = sorted.size / 2
  sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
end
without, with = pairs.transpose.map { |times| (median.(times) * 1000).round(1) }
puts "Ranking, median over #{pairs.size} readings: #{without} ms text only, #{with} ms with art (+#{(with - without).round(1)} ms; target ≤ 50 ms)."
