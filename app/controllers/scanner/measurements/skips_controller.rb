# Records that a manifest row's card wasn't to hand (spec 007 AC-5.5).
class Scanner::Measurements::SkipsController < ApplicationController
  include MeasurementMode

  def create
    row = measurement_run.row(params.expect(:file))
    return head(:not_found) unless row

    measurement_run.skip!(row)
    render_panel "Skipped #{row.file}."
  end
end
