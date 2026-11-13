# Stand-ins for Bundler's gem specs, so the reader of the third-party licences (spec 087) is specced without the real
# bundle: a gem directory under a temp directory with the files named, and the five readers the reader asks.
module ThirdPartyLicencesHelpers
  # What the reader asks of a Bundler spec: name, version, licenses, homepage and full_gem_path, and nothing else.
  StandIn = Struct.new(:name, :version, :licenses, :homepage, :full_gem_path, keyword_init: true)

  # A gem spec stand-in whose directory and files exist on disk, so a spec shows what the reader finds there.
  #
  # @param dir [Pathname] a temp directory the spec owns and removes
  # @param name [String] the gem's name, also its directory name under `dir`
  # @param version [String] the gem's version
  # @param licenses [Array<String>] the licence identifiers the gem declares
  # @param homepage [String, nil] the homepage the gem declares
  # @param files [Hash{String=>String}] file name to text, written in the gem's directory
  # @return [StandIn]
  def stand_in_gem(dir, name: "example", version: "1.2.3", licenses: [ "MIT" ], homepage: "https://example.test", files: {})
    path = dir.join(name)
    path.mkpath
    files.each { |file, text| path.join(file).write(text) }
    StandIn.new(name:, version: Gem::Version.new(version), licenses:, homepage:, full_gem_path: path.to_s)
  end
end

RSpec.configure do |config|
  config.include ThirdPartyLicencesHelpers
end
