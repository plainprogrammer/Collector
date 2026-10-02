require "openssl"
require "socket"
require "fileutils"

module Collector
  # Self-signed HTTPS for the dev server on the local network (spec 007 AC-7.1): a certificate for the LAN
  # address that a phone trusts once, kept outside the repository, served by Puma's ssl:// bind. Stdlib only:
  # loaded by bin/dev-certificate without the app.
  module DevCertificate
    DIR = ENV.fetch("COLLECTOR_DEV_CERT_DIR", File.expand_path("~/.local/share/collector-dev-https"))
    VALID_DAYS = 397 # Apple rejects TLS certificates valid for more than 398 days.
    RENEW_DAYS = 30
    DAY = 86_400
    CONTENT_TYPE = "application/x-x509-ca-cert".freeze
    FILENAME = "collector-dev.crt".freeze

    module_function

    def lan_addresses
      Socket.ip_address_list.select(&:ipv4_private?).map(&:ip_address).uniq.sort
    end

    # Returns { key:, cert:, created: }; keeps the existing pair while it still fits.
    def ensure!(dir:, addresses:, now: Time.now)
      key_path = File.join(dir, "dev.key")
      cert_path = File.join(dir, "dev.crt")
      paths = { key: key_path, cert: cert_path }
      return paths.merge(created: false) if reusable?(key_path, cert_path, addresses, now)

      FileUtils.mkdir_p(dir)
      File.chmod(0o700, dir)
      key = OpenSSL::PKey::RSA.new(2048)
      write_private(key_path, key.to_pem)
      File.write(cert_path, build(key, addresses, now).to_pem)
      paths.merge(created: true)
    end

    # Answers every GET with the certificate (never anything else) until interrupted. Yields the bound port.
    def serve(cert_path, port:, host: "0.0.0.0")
      body = File.binread(cert_path)
      server = TCPServer.new(host, port)
      yield server.addr[1] if block_given?
      loop do
        client = server.accept
        begin
          client.gets # request line; headers are ignored
          client.write("HTTP/1.1 200 OK\r\nContent-Type: #{CONTENT_TYPE}\r\n" \
                       "Content-Disposition: attachment; filename=\"#{FILENAME}\"\r\n" \
                       "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n", body)
        rescue SystemCallError, IOError
          nil # a client that hangs up early doesn't stop the server
        ensure
          client.close
        end
      end
    ensure
      server&.close
    end

    def reusable?(key_path, cert_path, addresses, now)
      return false unless File.file?(key_path) && File.file?(cert_path)

      cert = OpenSSL::X509::Certificate.new(File.read(cert_path))
      key = OpenSSL::PKey::RSA.new(File.read(key_path))
      san = cert.extensions.find { |e| e.oid == "subjectAltName" }&.value.to_s.split(", ")
      cert.check_private_key(key) &&
        addresses.all? { |address| san.include?("IP Address:#{address}") } &&
        cert.not_after - now >= RENEW_DAYS * DAY
    rescue OpenSSL::OpenSSLError
      false
    end

    def build(key, addresses, now)
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = OpenSSL::BN.rand(128)
      cert.subject = cert.issuer = OpenSSL::X509::Name.parse("/CN=Collector dev #{addresses.first}")
      cert.public_key = key.public_key
      cert.not_before = now - 60
      cert.not_after = now + (VALID_DAYS * DAY)
      ext = OpenSSL::X509::ExtensionFactory.new(cert, cert)
      san = (addresses.map { |a| "IP:#{a}" } + [ "IP:127.0.0.1", "DNS:localhost" ]).uniq.join(",")
      [
        ext.create_extension("basicConstraints", "CA:TRUE", true),
        ext.create_extension("keyUsage", "digitalSignature,keyEncipherment,keyCertSign", true),
        ext.create_extension("extendedKeyUsage", "serverAuth"),
        ext.create_extension("subjectAltName", san),
        ext.create_extension("subjectKeyIdentifier", "hash")
      ].each { |e| cert.add_extension(e) }
      cert.sign(key, OpenSSL::Digest.new("SHA256"))
      cert
    end

    # Writes to a 0600 temp file, then renames, so the key is never readable by others, even briefly.
    def write_private(path, content)
      tmp = "#{path}.#{Process.pid}.tmp"
      File.open(tmp, File::WRONLY | File::CREAT | File::TRUNC, 0o600) { |f| f.write(content) }
      File.chmod(0o600, tmp)
      File.rename(tmp, path)
    end
  end
end
