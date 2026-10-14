class ApplicationController < ActionController::Base
  include FirstRun
  include Authentication
  include CardContext

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    # The browser only prefetched this page: nobody saw it (spec 006 AC-1.10, spec 023 decision 4).
    def prefetch?
      %w[Sec-Purpose X-Sec-Purpose X-Moz Purpose].any? { |header| request.headers[header].to_s.include?("prefetch") }
    end
end
