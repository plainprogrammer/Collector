# Removes a failed job, after a confirmation page that works without scripting (spec 015 AC-6.7, AC-6.8).
class Admin::Jobs::DiscardsController < ApplicationController
  include AdminOnly

  before_action :set_job

  def new
    redirect_to admin_jobs_path, alert: "That job isn't failed any more.", status: :see_other unless @job.failed?
  end

  def create
    if @job.discard
      redirect_to admin_jobs_path(status: "failed"), notice: "Discarded #{@job.class_name}.", status: :see_other
    else
      redirect_to admin_jobs_path, alert: "That job isn't failed any more.", status: :see_other
    end
  end

  private
    def set_job = @job = BackgroundJobs::Entry.find(params[:job_id])
end
