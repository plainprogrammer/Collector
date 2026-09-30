# Loads the Phase 0 spike code (spec 005) for its specs; these are not part of bin/ci.
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "card_scanner_spike"
