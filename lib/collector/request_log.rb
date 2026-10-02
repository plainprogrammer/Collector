require "json"

module Collector
  # Development-only log of each response's size, for the scanner's cold and warm iPhone loads (spec 007 AC-6.5),
  # as spec 005's spike server logged them: one JSON line per response once its body has been sent.
  class RequestLog
    def initialize(app, path:)
      @app = app
      @path = path
    end

    def call(env)
      status, headers, body = @app.call(env)
      request = Rack::Request.new(env)
      [ status, headers, CountingBody.new(body) { |bytes| log(request, status, bytes) } ]
    end

    private
      def log(request, status, bytes)
        File.open(@path, "a") do |file|
          file.puts(JSON.generate(at: Time.now.utc.iso8601(3), method: request.request_method, path: request.path,
            status:, bytes:, user_agent: request.user_agent))
        end
      end

    class CountingBody
      def initialize(body, &on_close)
        @body = body
        @on_close = on_close
        @bytes = 0
      end

      def each
        @body.each do |chunk|
          @bytes += chunk.bytesize
          yield chunk
        end
      end

      def close
        @body.close if @body.respond_to?(:close)
        @on_close.call(@bytes)
      end
    end
  end
end
