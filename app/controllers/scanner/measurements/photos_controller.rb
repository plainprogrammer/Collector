# Serves a manifest row's photo to the local photo replay (script/scanner/photo_run.rb), which hands it to the
# scanner's photo picker (spec 007 Story 6, AC-6.2).
class Scanner::Measurements::PhotosController < ApplicationController
  include MeasurementMode
  allow_unauthenticated_access
  before_action :require_local_request

  def show
    row = measurement_run.row(params[:id])
    path = row && measurement_run.photo_path(row)
    return head(:not_found) unless path

    send_file path, type: Marcel::MimeType.for(path, name: path.basename.to_s), disposition: :inline
  end
end
