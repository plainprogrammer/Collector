# Removes expired stored uploads and orphaned upload blobs (spec 028 decision 9). Idempotent; queued every 15 minutes
# by config/recurring.yml. It has no retry_on: a run that fails is followed by the next one, and the sweep rescues and
# logs per item, so one failing item never stops the others.
class ImportUpload::SweepJob < ApplicationJob
  queue_as :default

  def perform = ImportUpload.sweep!
end
