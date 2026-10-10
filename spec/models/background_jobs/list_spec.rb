require "rails_helper"

RSpec.describe BackgroundJobs::List, :solid_queue, type: :model do
  def list(state = "failed", page: nil) = described_class.new(state:, page:)

  def ids(state) = list(state).entries.map(&:id)

  it "counts the jobs in each state, with jobs waiting on a concurrency limit among the queued (spec 015 AC-6.1)" do
    fail_job(queue_job(MTG::Art::BuildJob))
    claim_job(queue_job(MTG::Art::BuildJob))
    queue_job(Catalog::RefreshJob, "mtg", "manual")
    queue_job(Catalog::RefreshJob, "mtg", "manual") # blocked behind the first
    queue_job(MTG::Art::BuildJob, wait: 5.minutes)
    finish_job(queue_job(MTG::Art::BuildJob))

    expect(list.counts).to eq("failed" => 1, "running" => 1, "queued" => 2, "scheduled" => 1)
  end

  it "shows the failed list for an unknown state", :aggregate_failures do
    expect(list("paused").state).to eq("failed")
    expect(list("queued").state).to eq("queued")
  end

  describe "#entries (AC-6.2)" do
    it "lists failed jobs, the latest failure first" do
      first = queue_job(MTG::Art::BuildJob)
      second = queue_job(MTG::Art::BuildJob)
      travel_to(2.minutes.ago) { fail_job(second) }
      fail_job(first)

      expect(ids("failed")).to eq([ first.id, second.id ])
    end

    it "lists running jobs, the latest start first" do
      first = queue_job(MTG::Art::BuildJob)
      second = queue_job(MTG::Art::BuildJob)
      travel_to(2.minutes.ago) { claim_job(first) }
      claim_job(second)

      expect(ids("running")).to eq([ second.id, first.id ])
    end

    it "lists queued jobs oldest first, ready and waiting together", :aggregate_failures do
      ready = travel_to(3.minutes.ago) { queue_job(Catalog::RefreshJob, "mtg", "manual") }
      waiting = travel_to(2.minutes.ago) { queue_job(Catalog::RefreshJob, "mtg", "scheduled") }
      other = queue_job(MTG::Art::BuildJob)

      expect(ids("queued")).to eq([ ready.id, waiting.id, other.id ])
      expect(list("queued").entries.map(&:state)).to eq(%i[queued waiting queued])
    end

    it "lists scheduled jobs, the soonest due first" do
      later = queue_job(MTG::Art::BuildJob, wait: 10.minutes)
      sooner = queue_job(MTG::Art::BuildJob, wait: 5.minutes)

      expect(ids("scheduled")).to eq([ sooner.id, later.id ])
    end

    it "shows 25 jobs a page and clamps the page to those there are", :aggregate_failures do
      26.times { fail_job(queue_job(MTG::Art::BuildJob)) }

      expect(list("failed").entries.size).to eq(25)
      expect(list("failed", page: "2").entries.size).to eq(1)
      expect(list("failed", page: "99").pagination).to have_attributes(page: 2, total_pages: 2)
      expect(list("failed", page: "nope").pagination.page).to eq(1)
    end
  end

  describe "#live? and .live? (AC-6.10)" do
    it "is live only while a job is running or queued, not for failed or scheduled ones", :aggregate_failures do
      fail_job(queue_job(MTG::Art::BuildJob))
      queue_job(MTG::Art::BuildJob, wait: 5.minutes)
      expect([ list.live?, described_class.live? ]).to eq([ false, false ])

      queued = queue_job(Catalog::RefreshJob, "mtg", "manual")
      expect([ list.live?, described_class.live? ]).to eq([ true, true ])

      claim_job(queued)
      expect([ list.live?, described_class.live? ]).to eq([ true, true ])
    end

    it "is live for a job waiting on a concurrency limit alone" do
      queue_job(Catalog::RefreshJob, "mtg", "manual").ready_execution.delete
      queue_job(Catalog::RefreshJob, "mtg", "manual")

      expect(described_class.live?).to be(true)
    end
  end
end
