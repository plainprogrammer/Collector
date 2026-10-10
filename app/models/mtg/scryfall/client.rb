require "net/http"

# Minimal Scryfall HTTP client following https://scryfall.com/docs/api:
# descriptive headers, >= 100 ms between API calls, back-off on 429, timeouts.
class MTG::Scryfall::Client
  API_ROOT = "https://api.scryfall.com"
  USER_AGENT = "Collector/1.0 (+https://github.com/plainprogrammer/Collector)"
  MIN_INTERVAL = 0.1
  MAX_ATTEMPTS = 3
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 60
  NETWORK_ERRORS = [ Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, EOFError ].freeze

  def initialize(sleeper: ->(seconds) { sleep(seconds) }, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
    @sleeper = sleeper
    @clock = clock
    @last_request_at = nil
  end

  # Accepts an API path ("/sets") or a full API URL (a "next_page" link).
  def get_json(path_or_url)
    uri = URI.join(API_ROOT, path_or_url)
    MAX_ATTEMPTS.times do |attempt|
      throttle
      response = request(uri) { |http, request| http.request(request) }
      return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
      raise Catalog::Sources::TransientError, "GET #{uri} returned #{response.code}" unless response.is_a?(Net::HTTPTooManyRequests)

      @sleeper.call(Integer(response["Retry-After"].to_s, exception: false) || 2**attempt)
    end
    raise Catalog::Sources::TransientError, "GET #{uri} still rate limited after #{MAX_ATTEMPTS} attempts"
  end

  # Streams the body into the given IO. With a block, yields the bytes received so far after each chunk (spec 015 FR-2).
  def download(url, to:)
    uri = URI(url)
    received = 0
    request(uri) do |http, request|
      http.request(request) do |response|
        raise Catalog::Sources::TransientError, "GET #{uri} returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        response.read_body do |chunk|
          to.write(chunk)
          yield received += chunk.bytesize if block_given?
        end
      end
    end
  end

  # A card image (spec 011 AC-3.4): throttled like API calls, Accept image/jpeg, retried with back-off on 429 and 5xx
  # (Retry-After when given, else 1, 2 s), at most MAX_ATTEMPTS requests. Returns the body's bytes.
  def fetch_image(url)
    uri = URI(url)
    MAX_ATTEMPTS.times do |attempt|
      throttle
      response = request(uri, accept: "image/jpeg") { |http, request| http.request(request) }
      return response.body.to_s.b if response.is_a?(Net::HTTPSuccess)
      raise Catalog::Sources::TransientError, "GET #{uri} returned #{response.code}" unless retryable?(response)

      @sleeper.call(Integer(response["Retry-After"].to_s, exception: false) || 2**attempt) if attempt < MAX_ATTEMPTS - 1
    end
    raise Catalog::Sources::TransientError, "GET #{uri} still failing after #{MAX_ATTEMPTS} attempts"
  end

  private
    def request(uri, accept: "application/json")
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        yield http, Net::HTTP::Get.new(uri, "User-Agent" => USER_AGENT, "Accept" => accept)
      end
    rescue *NETWORK_ERRORS => error
      raise Catalog::Sources::TransientError, "GET #{uri}: #{error.class}: #{error.message}"
    end

    def retryable?(response) = response.is_a?(Net::HTTPTooManyRequests) || response.is_a?(Net::HTTPServerError)

    def throttle
      if @last_request_at
        wait = MIN_INTERVAL - (@clock.call - @last_request_at)
        @sleeper.call(wait.round(3)) if wait.positive?
      end
      @last_request_at = @clock.call
    end
end
