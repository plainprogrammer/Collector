# The HTTP side of the behaviour checks (spec 031 Story 5): a client that keeps cookies, signs in at the form with its CSRF
# token as a browser does, and never follows a redirect.
require "net/http"

module Upgrade
  class Web
    Response = Struct.new(:status, :body)

    CSRF = /<meta name="csrf-token" content="([^"]*)"/
    UNREACHABLE = [ Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EPIPE, EOFError, SocketError, Net::OpenTimeout, Net::ReadTimeout ].freeze

    # The sign-up page answers 200 whether sign-up is open or closed; only the open one has this field (AC-5.3).
    def self.signup_form?(body) = body.include?('name="user[email_address]"')

    def initialize(port, host: "127.0.0.1")
      @host = host
      @port = port
      @cookies = {}
    end

    def get(path) = send_request(Net::HTTP::Get.new(path))

    def status(path) = get(path).status

    def sign_in(email, password)
      token = CSRF.match(get("/session/new").body)&.captures&.first
      return false unless token

      request = Net::HTTP::Post.new("/session")
      request.set_form_data("authenticity_token" => token, "email_address" => email, "password" => password)
      [ 302, 303 ].include?(send_request(request).status)
    end

    private
      def send_request(request)
        request["Cookie"] = @cookies.map { |name, value| "#{name}=#{value}" }.join("; ") unless @cookies.empty?
        Net::HTTP.start(@host, @port, open_timeout: 5, read_timeout: 30) do |http|
          response = http.request(request)
          response.get_fields("set-cookie")&.each do |cookie|
            name, value = cookie.split(";", 2).first.split("=", 2)
            @cookies[name] = value
          end
          Response.new(response.code.to_i, response.body.to_s)
        end
      rescue *UNREACHABLE
        Response.new(0, "")
      end
  end
end
