# Serves the self-hosted OCR engine (spec 007 AC-2.2, ADR 0001): only the pinned files, from a path that
# carries the version, cacheable as immutable for a year; If-None-Match or If-Modified-Since gets 304.
# The engine is a public library, so no sign-in is needed.
class OcrAssetsController < ApplicationController
  allow_unauthenticated_access
  allow_before_first_user
  # GET-only public library, loaded by the scanner page as scripts and workers: Rails' cross-origin
  # JavaScript check would answer every .js file with 422. Nothing here reads or changes session state.
  skip_forgery_protection

  def show
    engine = ::Collector::OcrEngine # bare Collector would find ActionController::MimeResponds::Collector
    path = engine.path_for(params[:path]) if params[:version] == engine::VERSION
    return head(:not_found) unless path && File.file?(path)

    expires_in 365.days, public: true, immutable: true # 31536000 s; 1.year is 365.2425 days
    return unless stale?(etag: engine::FILES.fetch(params[:path]), last_modified: engine::PUBLISHED_AT, public: true)

    send_file path, type: engine.content_type(path), disposition: :inline
  end
end
