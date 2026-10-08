# Spec 011 AC-3.10, ADR 0011: the build's zero-offset fingerprints of spec 010's 134 agreement images, one "<id> <hex>"
# line each, so the production image's ImageMagick can be compared with the desktop's.
#   bin/rails runner script/scanner/art_decoder_fingerprints.rb ~/card-scanner-corpus/art-cache
dir = Pathname(File.expand_path(ARGV.fetch(0)))
warn "decoder: #{MTG::Art::Decoder.command}"
JSON.parse(dir.join("agreement_small.json").read).fetch("results").each do |result|
  path = dir.join("artwork/small/#{result.fetch("id")}.jpg")
  puts "#{result["id"]} #{MTG::Art::Fingerprint.of(MTG::Art::Decoder.decode(path)).unpack1("H*")}"
end
