# Chooses which framing measurement mode draws, crops and stores under (spec 082 decision 5): the live guide ("full") or the
# shipped card size in the tall stage ("shipped"), kept in the session so every later write of the paired run reaches its run.
class Scanner::Measurements::FramingsController < ApplicationController
  include MeasurementMode

  def update
    framing = params.expect(:framing).to_s
    return head(:unprocessable_content) unless Scanner::MeasurementRun::FRAMINGS.include?(framing)

    session[:scanner_framing] = framing
    redirect_to scanner_measurement_path, status: :see_other
  end
end
