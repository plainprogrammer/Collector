# Spec 009 NFR Performance: how much the scanner page's own assets grew, gzip -9, against main. The page loads every
# Stimulus controller and scanner module through the import map, and the app's stylesheets.
# Usage: bundle exec ruby script/scanner/asset_growth.rb
require "open3"
require "stringio"
require "zlib"

PATTERNS = %w[app/javascript/controllers app/javascript/scanner app/assets/stylesheets/collector].freeze

def gzip_size(text)
  return 0 if text.nil?

  io = StringIO.new
  Zlib::GzipWriter.wrap(io, Zlib::BEST_COMPRESSION) { it.write(text) }
  io.string.bytesize
end

def at_main(path)
  text, _missing, status = Open3.capture3("git", "show", "main:#{path}") # a file new since main is not an error
  status.success? ? text : nil
end

now = PATTERNS.flat_map { Dir["#{it}/**/*.{js,css}"] }
before = Open3.capture2("git", "ls-tree", "-r", "--name-only", "main", *PATTERNS).first.lines(chomp: true).grep(/\.(js|css)\z/)
rows = (now | before).sort.map { |path| [ path, gzip_size(at_main(path)), gzip_size(File.exist?(path) ? File.read(path) : nil) ] }
rows.reject { _2 == _3 }.each { |path, was, is| puts format("%-60s %7d -> %7d (%+d)", path, was, is, is - was) }
growth = rows.sum { _3 - _2 }
puts "Total growth, gzip -9: #{growth} bytes (target: at most 20 KB = 20,480 bytes)"
