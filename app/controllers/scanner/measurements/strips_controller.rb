# Serves a measured capture's stored strip to the local desktop replay (spec 007 AC-5.6).
class Scanner::Measurements::StripsController < ApplicationController
  include MeasurementMode
  allow_unauthenticated_access
  before_action :require_local_request

  def show
    row = measurement_run.row(params[:id])
    path = row && measurement_run.strip_path(row, params[:strip])
    return head(:not_found) unless path&.file?

    send_file path, type: "image/png", disposition: :inline
  end
end
