require "rails_helper"
require "socket"
require Rails.root.join("script/upgrade/web").to_s

RSpec.describe Upgrade::Web do
  # routes: a callable (method, path, head, body) -> [status, headers, body]
  def serve(routes)
    server = TCPServer.new("127.0.0.1", 0)
    thread = Thread.new do
      loop do
        client = server.accept
        head = +""
        while (line = client.gets) && line != "\r\n"
          head << line
        end
        method, path = head.lines.first.to_s.split
        length = head[/content-length: (\d+)/i, 1].to_i
        body = length.positive? ? client.read(length) : ""
        status, headers, payload = routes.call(method, path, head, body)
        client.write("HTTP/1.1 #{status} X\r\n#{headers.map { |key, value| "#{key}: #{value}\r\n" }.join}Content-Length: #{payload.bytesize}\r\nConnection: close\r\n\r\n#{payload}")
        client.close
      end
    rescue IOError, Errno::EBADF
      nil
    end
    [ server, thread ]
  end

  let(:routes) do
    lambda do |method, path, head, body|
      case [ method, path ]
      when [ "GET", "/session/new" ] then [ 200, {}, '<meta name="csrf-token" content="tok123" />' ]
      when [ "POST", "/session" ]
        good = body.include?("authenticity_token=tok123") && body.include?("password=right")
        good ? [ 303, { "Set-Cookie" => "sid=abc; path=/; HttpOnly" }, "" ] : [ 422, {}, "no" ]
      when [ "GET", "/collection" ] then head.include?("Cookie: sid=abc") ? [ 200, {}, "Dragon" ] : [ 302, {}, "" ]
      else [ 404, {}, "" ]
      end
    end
  end

  let!(:listener) { serve(routes) }
  let(:port) { listener.first.addr[1] }
  let(:web) { described_class.new(port) }

  after do
    listener.first.close
    listener.last.kill
  end

  it "signs in with the form's CSRF token and keeps the session cookie (AC-5.1)", :aggregate_failures do
    expect(web.get("/collection").status).to eq(302)
    expect(web.sign_in("ada@x.test", "right")).to be(true)
    expect(web.get("/collection").body).to eq("Dragon")
  end

  it "reports a refused sign-in" do
    expect(web.sign_in("ada@x.test", "wrong")).to be(false)
  end

  it "answers status 0 when nothing listens" do
    closed_port = port
    listener.first.close
    expect(described_class.new(closed_port).status("/up")).to eq(0)
  end

  it "tells the sign-up form from the closed notice by its email field (AC-5.3)", :aggregate_failures do
    expect(described_class.signup_form?('<input name="user[email_address]" type="email">')).to be(true)
    expect(described_class.signup_form?("<p>Sign-up is closed.</p>")).to be(false)
  end
end
