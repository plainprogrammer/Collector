# The admin jobs pages (spec 015 Story 6, ADR 0014): the queue's jobs by state, and one job in full.
class Admin::JobsController < ApplicationController
  include AdminOnly

  def index
    @list = BackgroundJobs::List.new(state: params[:status].to_s, page: params[:page])
  end

  def show
    @job = BackgroundJobs::Entry.find(params[:id])
    @live = BackgroundJobs::List.live?
  end
end
