module Collector
  # bin/setup's libvips check (spec 014, ADR 0013). libvips is available when ruby-vips loads in the app's bundle.
  # A direct bin/setup doesn't run under Bundler, so the default probe asks a bundled Ruby rather than requiring the
  # gem in this process, which could find a copy installed outside the bundle. Stdlib only.
  class LibvipsCheck
    PROBE = [ "bundle", "exec", "ruby", "-e", 'require "ruby-vips"' ].freeze
    HINT = "libvips isn't available, so Active Storage can't make image variants (ADR 0013). Install it " \
           "(e.g. `sudo dnf install vips` or `sudo apt install libvips`), then run bin/setup again.".freeze

    def initialize(probe: -> { system(*PROBE, out: File::NULL, err: File::NULL) })
      @probe = probe
    end

    # The hint to print, or nil when libvips is available.
    def hint
      HINT unless available?
    end

    private

    def available?
      @probe.call ? true : false
    rescue StandardError
      false
    end
  end
end
