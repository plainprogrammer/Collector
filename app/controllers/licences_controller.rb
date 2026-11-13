# The third-party licences (spec 087): every component in the image and its licence, for everyone, with no tenant data.
#
# @see file:catalog-core.md
class LicencesController < ApplicationController
  allow_unauthenticated_access
  allow_before_first_user
  before_action :resume_session # allow_unauthenticated_access alone never resumes a session; the header needs to know who is here

  def show
    # `::Collector`, because inside a controller a bare `Collector` is ActionController::MimeResponds::Collector.
    @sections = ::Collector::ThirdPartyLicences.current.sections
  end
end
