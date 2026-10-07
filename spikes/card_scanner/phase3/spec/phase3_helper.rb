# Loads the art spike's code (spec 010) for its specs; these are not part of bin/ci.
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "card_scanner_phase3"
