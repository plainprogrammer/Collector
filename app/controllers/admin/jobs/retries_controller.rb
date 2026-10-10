# Queues a failed job to run again (spec 015 AC-6.6, AC-6.8).
class Admin::Jobs::RetriesController < ApplicationController
  include AdminOnly

  def create
    job = BackgroundJobs::Entry.find(params[:job_id])
    if job.retry
      redirect_to admin_jobs_path(status: "failed"), notice: "Retrying #{job.class_name}.", status: :see_other
    else
      redirect_to admin_jobs_path, alert: "That job isn't failed any more.", status: :see_other
    end
  end
end
