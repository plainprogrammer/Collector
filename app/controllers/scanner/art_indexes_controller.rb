# Serves the art index the build wrote (spec 011 Story 4; ADR 0007): only the current or previous file, by its exact
# name, pre-compressed whatever the request's Accept-Encoding (every supported browser takes gzip), cacheable as immutable
# for a year (a new index always has a new name). Global catalog data: no sign-in, nothing tenant-scoped (AC-4.4).
class Scanner::ArtIndexesController < ApplicationController
  allow_unauthenticated_access
  allow_before_first_user

  def show
    path = MTG::Art.enabled? ? MTG::Art::Index.path_for(params[:name]) : nil
    return head(:not_found) unless path

    expires_in 365.days, public: true, immutable: true # 31536000 s
    return unless stale?(etag: path.basename.to_s, last_modified: path.mtime, public: true)

    response.headers["Content-Encoding"] = "gzip"
    send_file path, type: "application/octet-stream", disposition: :inline
  end
end
