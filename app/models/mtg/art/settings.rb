# The art fingerprint's settings (ADR 0006), the one source the build and the scanner page share (spec 011 AC-8.1):
# config/art_fingerprint.json, frozen at 39cdc6e. Its digest is recorded with every stored fingerprint, in the index
# header and on the page, so a change of settings can never mix fingerprints.
module MTG::Art::Settings
  PATH = Rails.root.join("config/art_fingerprint.json")

  def self.fingerprint = @fingerprint ||= JSON.parse(PATH.read).freeze

  def self.digest = @digest ||= Digest::SHA256.hexdigest(JSON.generate(fingerprint))[0, 16]

  def self.for_page = { "digest" => digest, "fingerprint" => fingerprint }
end
