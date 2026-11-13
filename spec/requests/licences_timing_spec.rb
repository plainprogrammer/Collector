require "rails_helper"

# Spec 087 AC-1.9: what the real page costs, measured and never gating (run with SCANNER_TIMING=1, as spec/rails_helper.rb
# documents); the figures go in verification.md. The first request builds the list from the bundle and is left out of the
# 20 that are timed: the list is kept for the process (decision 3).
RSpec.describe "Licences page timing", :timing, type: :request do
  it "renders the real page over 20 requests, with its median, maximum and size", :aggregate_failures do
    get licences_path
    times = Array.new(20) do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      get licences_path
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(1)
    end.sort

    median = (times[9] + times[10]) / 2
    RSpec.configuration.reporter.message format("licences page: median %.1f ms, max %.1f ms, %d bytes", median, times.last, response.body.bytesize)
    expect(response).to have_http_status(:ok)
  end
end
