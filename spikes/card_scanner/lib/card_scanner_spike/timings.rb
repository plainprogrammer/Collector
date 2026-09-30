require "json"

module CardScannerSpike
  # Splits the spike server's request log into one device's page loads (AC-1.6).
  module Timings
    Session = Data.define(:started_at, :requests, :bytes)
    PAGE = "/ocr.html"

    module_function

    def sessions(lines, ip:)
      lines.map { JSON.parse(it) }.select { it["ip"] == ip }
        .slice_before { it["method"] == "GET" && it["path"] == PAGE }
        .select { it.first["path"] == PAGE }
        .map { Session.new(started_at: it.first["at"], requests: it.size, bytes: it.sum { |entry| entry["bytes"] }) }
    end
  end
end
