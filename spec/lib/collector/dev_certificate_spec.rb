require "rails_helper"
require "tmpdir"
require "net/http"

RSpec.describe Collector::DevCertificate do
  let(:dir) { File.join(Dir.mktmpdir, "certs") }
  let(:lan) { "192.168.1.76" }
  let(:now) { Time.now }

  after { FileUtils.remove_entry(File.dirname(dir)) }

  def ensure_pair(addresses: [ lan ], at: now)
    described_class.ensure!(dir: dir, addresses: addresses, now: at)
  end

  def certificate(paths) = OpenSSL::X509::Certificate.new(File.read(paths[:cert]))

  def extension(cert, oid) = cert.extensions.find { |e| e.oid == oid }&.value

  describe "DIR" do
    it "defaults outside the repository" do
      expect(described_class::DIR).to eq(ENV.fetch("COLLECTOR_DEV_CERT_DIR", File.expand_path("~/.local/share/collector-dev-https")))
    end
  end

  describe ".lan_addresses" do
    it "returns the private IPv4 addresses, sorted" do
      addresses = described_class.lan_addresses
      expect(addresses).to eq(addresses.sort).and(all(satisfy { |a| Addrinfo.ip(a).ipv4_private? }))
    end
  end

  describe ".ensure!" do
    it "writes a CA certificate the phone can trust for the address", :aggregate_failures do
      paths = ensure_pair
      cert = certificate(paths)
      expect(paths[:created]).to be(true)
      expect(cert.version).to eq(2)
      expect(cert.signature_algorithm).to eq("sha256WithRSAEncryption")
      expect(cert.subject.to_s).to eq("/CN=Collector dev #{lan}")
      expect(extension(cert, "basicConstraints")).to eq("CA:TRUE")
      expect(extension(cert, "keyUsage")).to include("Digital Signature", "Key Encipherment", "Certificate Sign")
      expect(extension(cert, "extendedKeyUsage")).to eq("TLS Web Server Authentication")
      expect(extension(cert, "subjectAltName")).to include("IP Address:#{lan}", "IP Address:127.0.0.1", "DNS:localhost")
      expect(extension(cert, "subjectKeyIdentifier")).to be_present
      expect(cert.not_after - cert.not_before).to be <= 398 * 86_400
    end

    it "keeps the key private", :aggregate_failures do
      paths = ensure_pair
      expect(File.stat(dir).mode & 0o777).to eq(0o700)
      expect(File.stat(paths[:key]).mode & 0o777).to eq(0o600)
    end

    it "writes a key that matches the certificate" do
      paths = ensure_pair
      key = OpenSSL::PKey::RSA.new(File.read(paths[:key]))
      expect(certificate(paths).check_private_key(key)).to be(true)
    end

    it "reuses a valid pair", :aggregate_failures do
      first = certificate(ensure_pair)
      again = ensure_pair(at: now + (30 * 86_400))
      expect(again[:created]).to be(false)
      expect(certificate(again).serial).to eq(first.serial)
    end

    it "regenerates when an address isn't covered", :aggregate_failures do
      first = certificate(ensure_pair)
      again = ensure_pair(addresses: [ lan, "10.0.0.5" ])
      expect(again[:created]).to be(true)
      expect(certificate(again).serial).not_to eq(first.serial)
      expect(extension(certificate(again), "subjectAltName")).to include("IP Address:10.0.0.5")
    end

    it "regenerates when it expires within 30 days", :aggregate_failures do
      first = certificate(ensure_pair)
      again = ensure_pair(at: first.not_after - (29 * 86_400))
      expect(again[:created]).to be(true)
      expect(certificate(again).serial).not_to eq(first.serial)
    end

    it "regenerates when the key doesn't match", :aggregate_failures do
      paths = ensure_pair
      File.write(paths[:key], OpenSSL::PKey::RSA.new(2048).to_pem)
      again = ensure_pair
      expect(again[:created]).to be(true)
      expect(certificate(again).check_private_key(OpenSSL::PKey::RSA.new(File.read(again[:key])))).to be(true)
    end
  end

  describe ".serve" do
    it "answers any GET with the certificate, never the key", :aggregate_failures do
      paths = ensure_pair
      bound = Queue.new
      thread = Thread.new { described_class.serve(paths[:cert], port: 0, host: "127.0.0.1") { |port| bound << port } }
      port = bound.pop

      %w[/ /dev.key /collector-dev.crt].each do |path|
        response = Net::HTTP.get_response(URI("http://127.0.0.1:#{port}#{path}"))
        expect(response.code).to eq("200")
        expect(response["Content-Type"]).to eq("application/x-x509-ca-cert")
        expect(response["Content-Disposition"]).to eq('attachment; filename="collector-dev.crt"')
        expect(response.body).to eq(File.read(paths[:cert]))
        expect(response.body).not_to include("PRIVATE KEY")
      end
    ensure
      thread&.kill&.join
    end
  end
end
