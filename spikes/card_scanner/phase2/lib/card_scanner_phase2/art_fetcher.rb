require "net/http"
require "uri"

module CardScannerPhase2
  # Fetches one image per artwork from Scryfall's image host with the project's manners (AC-4.7): a
  # descriptive User-Agent and Accept, at least 100 ms between requests, explicit timeouts, back-off on 429,
  # and a disk cache so a re-run fetches nothing twice. Failures after the retries are listed, not raised (AC-4.8).
  class ArtFetcher
    USER_AGENT = "Collector card scanner spike (+https://github.com/plainprogrammer/Collector)"
    MIN_INTERVAL = 0.1
    MAX_ATTEMPTS = 3

    def initialize(dir:, size:, http: method(:request), sleeper: method(:sleep), clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @dir, @size, @http, @sleeper, @clock = Pathname(dir).join(size), size, http, sleeper, clock
      @last = nil
    end

    def path_for(id) = @dir.join("#{id}.jpg")

    # artworks: { illustration_id => { "small" => url, "normal" => url } }. Returns the run's statistics.
    def fetch(artworks, limit: nil)
      @dir.mkpath
      stats = { "size" => @size, "fetched" => 0, "bytes" => 0, "skipped" => 0, "seconds" => 0.0, "failed" => [] }
      started = @clock.call
      artworks.each do |id, urls|
        break if limit && stats["fetched"] >= limit
        if path_for(id).file? && path_for(id).size.positive?
          stats["skipped"] += 1
          next
        end
        url = urls[@size] or raise FetchError, "no #{@size} image URL" # a few art-series printings carry none
        body = fetch_one(url)
        stats["fetched"] += 1
        stats["bytes"] += body.bytesize
        write(path_for(id), body)
      rescue FetchError => error
        stats["failed"] << { "id" => id, "error" => error.message }
      end
      stats["seconds"] = @clock.call - started
      stats
    end

    class FetchError < StandardError; end

    private
      def fetch_one(url)
        MAX_ATTEMPTS.times do |attempt|
          pace
          response = @http.call(url, { "User-Agent" => USER_AGENT, "Accept" => "image/jpeg" })
          case response.code.to_i
          when 200 then return response.body
          when 429, 500..599
            @sleeper.call((response["retry-after"] || 2**(attempt + 1)).to_f)
          else raise FetchError, "HTTP #{response.code}"
          end
        end
        raise FetchError, "HTTP 429 after #{MAX_ATTEMPTS} attempts"
      rescue SystemCallError, Net::OpenTimeout, Net::ReadTimeout, IOError => error
        raise FetchError, "#{error.class}: #{error.message}"
      end

      def pace
        now = @clock.call
        wait = @last ? MIN_INTERVAL - (now - @last) : MIN_INTERVAL
        @sleeper.call(wait) if wait.positive?
        @last = @clock.call
      end

      def write(path, body)
        partial = Pathname("#{path}.part")
        partial.binwrite(body)
        partial.rename(path)
      end

      def request(url, headers)
        uri = URI(url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) { |http| http.request(Net::HTTP::Get.new(uri, headers)) }
      end
  end
end
