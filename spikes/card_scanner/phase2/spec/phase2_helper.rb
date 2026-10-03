# Loads the Phase 2 spike code (spec 008) for its specs; these are not part of bin/ci.
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "card_scanner_phase2"
