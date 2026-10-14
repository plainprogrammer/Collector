require "net/http"

# Minimal Scryfall HTTP client following https://scryfall.com/docs/api:
# descriptive headers, >= 100 ms between API calls, back-off on 429, timeouts.
#
# The back-off is bounded (issue #74). A retry waits what Retry-After asks for, and never more than MAX_BACK_OFF: a
# longer wait, or a 429 on the last of MAX_ATTEMPTS requests, ends the call with Catalog::Sources::RateLimitedError,
# which carries the wait asked for, and leaves coming back to the caller (the jobs do, no sooner than that:
# Catalog::RateLimitRetry). So one call sleeps 60 seconds at most.
#
# Without a usable Retry-After the two retryable answers part ways (issue #81). A 5xx (images only) is retried after 1
# and then 2 seconds. A 429 isn't retried in the call at all: Scryfall limits access for RATE_LIMITED_FOR seconds after
# one, so a retry sooner can't succeed and counts as going on overloading it. The call ends at once with a
# RateLimitedError that carries no wait, and the job's retry, SHORTEST_WAIT (30 seconds) later, is the next request.
# Scryfall's pages don't say whether its 429 carries Retry-After, and none has been observed, so this may be the path
# every rate limit takes; a 429 that does carry a usable one is waited for as it asks.
class MTG::Scryfall::Client
  API_ROOT = "https://api.scryfall.com"
  USER_AGENT = "Collector/1.0 (+https://github.com/plainprogrammer/Collector)"
  MIN_INTERVAL = 0.1
  MAX_ATTEMPTS = 3
  # The longest wait before a retry, in seconds. Scryfall limits access for 30 seconds after a 429
  # (https://scryfall.com/docs/api/rate-limits), so a wait it asks for should fit; a longer one isn't slept through.
  MAX_BACK_OFF = 30
  # How long Scryfall says a 429 limits access for, in seconds (the same page). The client never asks again inside it
  # on its own guess: only a Retry-After from Scryfall itself brings a retry sooner.
  RATE_LIMITED_FOR = 30
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 60
  NETWORK_ERRORS = [ Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, EOFError ].freeze

  def initialize(sleeper: ->(seconds) { sleep(seconds) }, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
    @sleeper = sleeper
    @clock = clock
    @last_request_at = nil
  end

  # Accepts an API path ("/sets") or a full API URL (a "next_page" link). Retried only on a 429 that says how long to wait, with
  # the bounded back-off; a 429 that doesn't ends the call at once (issue #81).
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
  # 429 and 5xx (Retry-After when given and no more than MAX_BACK_OFF; without one, 1 and then 2 s after a 5xx and no
  # retry after a 429, issue #81), at most MAX_ATTEMPTS requests. Returns the body's bytes. Raises RateLimitedError
  # when it ends on a 429 or on a wait too long to sit out, and a plain TransientError when the image itself failed
  # (5xx to the end, another status, the network).
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

    # After a response worth a retry: waits what its Retry-After asks for, or, after a 5xx without one, 1 and then 2
    # seconds, so that the next attempt can follow. Or ends the call by raising, so every attempt's loop ends in a
    # return or here:
    # - a 429 with no usable Retry-After is never retried here, whichever attempt it answers (issue #81);
    # - a wait longer than MAX_BACK_OFF is never slept, so a worker can't be held for as long as a header says (#74);
    # - after the last attempt nothing is slept either, since a wait only serves a retry.
    # One call therefore waits (MAX_ATTEMPTS - 1) * MAX_BACK_OFF seconds at most, besides the time its requests take.
    def back_off(uri, response, attempt)
      wait = retry_after(response)
      raise limited_with_no_wait(uri) if wait.nil? && response.is_a?(Net::HTTPTooManyRequests)

      wait ||= 2**attempt
      if wait > MAX_BACK_OFF
        raise Catalog::Sources::RateLimitedError.new(
          "GET #{uri} returned #{response.code} and asked for #{wait} seconds before a retry; the client waits at most #{MAX_BACK_OFF}",
          retry_after: wait)
      end
      raise out_of_attempts(uri, response) if attempt + 1 == MAX_ATTEMPTS

      @sleeper.call(wait)
    end

    def limited_with_no_wait(uri)
      Catalog::Sources::RateLimitedError.new("GET #{uri} returned 429 with no usable Retry-After; Scryfall limits access for " \
        "#{RATE_LIMITED_FOR} seconds after a 429, so the client doesn't ask again in this call")
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
    # neither, or names a time already past: there is then nothing to honour, and sleep refuses a negative. What the
    # client does without one depends on the answer (#back_off).
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
