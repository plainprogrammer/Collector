require "net/http"

# Minimal Scryfall HTTP client following https://scryfall.com/docs/api:
# descriptive headers, >= 100 ms between API calls, back-off on 429, timeouts.
#
# The back-off is bounded (issue #74). A retry waits what Retry-After asks for, or 1 and then 2 seconds without one,
# and never more than MAX_BACK_OFF: a longer wait, or a 429 on the last of MAX_ATTEMPTS requests, ends the call with
# Catalog::Sources::RateLimitedError, which carries the wait asked for, and leaves coming back to the caller (the jobs
# do, no sooner than that: Catalog::RateLimitRetry). So one call sleeps 60 seconds at most.
class MTG::Scryfall::Client
  API_ROOT = "https://api.scryfall.com"
  USER_AGENT = "Collector/1.0 (+https://github.com/plainprogrammer/Collector)"
  MIN_INTERVAL = 0.1
  MAX_ATTEMPTS = 3
  # The longest wait before a retry, in seconds. Scryfall limits access for 30 seconds after a 429
  # (https://scryfall.com/docs/api/rate-limits), so a wait it asks for should fit; a longer one isn't slept through.
  MAX_BACK_OFF = 30
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 60
  NETWORK_ERRORS = [ Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, EOFError ].freeze

  def initialize(sleeper: ->(seconds) { sleep(seconds) }, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
    @sleeper = sleeper
    @clock = clock
    @last_request_at = nil
  end

  # Accepts an API path ("/sets") or a full API URL (a "next_page" link). Retried on 429 only, with the bounded back-off.
  def get_json(path_or_url)
    uri = URI.join(API_ROOT, path_or_url)
    MAX_ATTEMPTS.times do |attempt|
      throttle
      response = request(uri) { |http, request| http.request(request) }
      return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
      raise Catalog::Sources::TransientError, "GET #{uri} returned #{response.code}" unless response.is_a?(Net::HTTPTooManyRequests)

      back_off(uri, response, attempt)
    end
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

  # A card image (spec 011 AC-3.4): throttled like API calls, Accept image/jpeg, retried with the bounded back-off on
  # 429 and 5xx (Retry-After when given and no more than MAX_BACK_OFF, else 1, 2 s), at most MAX_ATTEMPTS requests.
  # Returns the body's bytes. Raises RateLimitedError when it ends on a 429 or on a wait too long to sit out, and a
  # plain TransientError when the image itself failed (5xx to the end, another status, the network).
  def fetch_image(url)
    uri = URI(url)
    MAX_ATTEMPTS.times do |attempt|
      throttle
      response = request(uri, accept: "image/jpeg") { |http, request| http.request(request) }
      return response.body.to_s.b if response.is_a?(Net::HTTPSuccess)
      raise Catalog::Sources::TransientError, "GET #{uri} returned #{response.code}" unless retryable?(response)

      back_off(uri, response, attempt)
    end
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

    # After a response worth a retry: waits what its Retry-After asks for, else 1, then 2 seconds, so that the next
    # attempt can follow. Or ends the call by raising (issue #74), so every attempt's loop ends in a return or here:
    # - a wait longer than MAX_BACK_OFF is never slept, so a worker can't be held for as long as a header says;
    # - after the last attempt nothing is slept either, since a wait only serves a retry.
    # One call therefore waits (MAX_ATTEMPTS - 1) * MAX_BACK_OFF seconds at most, besides the time its requests take.
    def back_off(uri, response, attempt)
      wait = retry_after(response) || 2**attempt
      if wait > MAX_BACK_OFF
        raise Catalog::Sources::RateLimitedError.new(
          "GET #{uri} returned #{response.code} and asked for #{wait} seconds before a retry; the client waits at most #{MAX_BACK_OFF}",
          retry_after: wait)
      end
      raise out_of_attempts(uri, response) if attempt + 1 == MAX_ATTEMPTS

      @sleeper.call(wait)
    end

    def out_of_attempts(uri, response)
      if response.is_a?(Net::HTTPTooManyRequests)
        Catalog::Sources::RateLimitedError.new("GET #{uri} still rate limited after #{MAX_ATTEMPTS} attempts",
          retry_after: retry_after(response))
      else
        Catalog::Sources::TransientError.new("GET #{uri} still failing after #{MAX_ATTEMPTS} attempts")
      end
    end

    # Retry-After in seconds, from a count of seconds or an HTTP date (RFC 9110). Nil when the header is missing, is
    # neither, or names a time already past: there is then nothing to honour, and sleep refuses a negative.
    def retry_after(response)
      value = response["Retry-After"].to_s.strip
      return value.to_i if value.match?(/\A\d+\z/)

      seconds = (Time.httpdate(value) - Time.current).ceil
      seconds unless seconds.negative?
    rescue ArgumentError
      nil
    end

    def throttle
      if @last_request_at
        wait = MIN_INTERVAL - (@clock.call - @last_request_at)
        @sleeper.call(wait.round(3)) if wait.positive?
      end
      @last_request_at = @clock.call
    end
end
