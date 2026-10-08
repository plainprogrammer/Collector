# Builds the art index in the background (spec 011 Story 3), queued by the catalog refresh (MTG::Art.after_refresh). Two
# builds never work at once: MTG::ArtBuild.start! guards it, keyed on the run record and this job's id, rather than a
# queue concurrency lock that a first build (hours) would outlast (AC-3.2). A missing ImageMagick fails the build run,
# which says so; retrying wouldn't help.
class MTG::Art::BuildJob < ApplicationJob
  queue_as :sync

  retry_on ActiveRecord::StatementTimeout, wait: :polynomially_longer, attempts: 3
  discard_on MTG::Art::Decoder::Error

  def perform = MTG::Art::Build.new(job_id:).call
end
