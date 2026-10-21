require "rails_helper"

RSpec.describe ImportUpload, type: :model do
  let(:account) { create(:user).account }
  let(:plan) { ImportHelpers::FakePlan.new("fp-1") }
  let(:service) { ActiveStorage::Blob.service }

  it "allows one per account (FR-10)", :aggregate_failures do
    account = create(:user).account
    described_class.create!(account:, fingerprint: "a", expires_at: 1.hour.from_now)

    expect { described_class.create!(account:, fingerprint: "b", expires_at: 1.hour.from_now) }
      .to raise_error(ActiveRecord::RecordNotUnique)
    expect(account.reload.import_upload.fingerprint).to eq("a")
  end

  def store(bytes = '{"a":1}', for_account: account) = described_class.store!(account: for_account, bytes:, plan:)

  describe ".store! (AC-5.1, AC-5.2)" do
    it "keeps the file as application/json, analyzed, expiring after EXPIRES_IN", :aggregate_failures do
      upload = store
      blob = upload.file.blob

      expect(blob.content_type).to eq("application/json")
      expect(blob).to be_analyzed
      expect(blob.metadata).to include("identified" => true, "import_upload" => true)
      expect(blob.filename.to_s).to match(/\Aimport-#{account.id}-\d{8}T\d{6}Z\.json\z/)
      expect(upload.fingerprint).to eq("fp-1")
      expect(upload.expires_at).to be_within(5.seconds).of(described_class::EXPIRES_IN.from_now)
      expect(upload.read).to eq('{"a":1}')
    end

    it "queues no job" do
      expect { store }.not_to have_enqueued_job
    end

    it "replaces the account's earlier upload and releases its file", :aggregate_failures do
      key = store("1").file.blob.key
      second = store("22")

      expect(account.reload.import_upload).to eq(second)
      expect(described_class.count).to eq(1)
      expect(ActiveStorage::Blob.exists?(key:)).to be(false)
      expect(service.exist?(key)).to be(false)
    end
  end

  describe "#expired? and #read" do
    it "is expired at expires_at, and reads nil when the file is gone", :aggregate_failures do
      upload = store
      expect(upload).not_to be_expired
      travel_to(described_class::EXPIRES_IN.from_now + 1.second) { expect(upload).to be_expired }

      service.delete(upload.file.blob.key)
      expect(upload.read).to be_nil
    end
  end

  describe "going with its account (AC-4.4)" do
    it "releases the blob and its file when the user is deleted" do
      user = create(:user)
      key = store(for_account: user.account).file.blob.key

      user.destroy!

      expect([ described_class.count, service.exist?(key) ]).to eq([ 0, false ])
    end
  end

  describe "a file that can't be deleted (decision 9, maintainer ruling 2026-10-20)" do
    it "still removes the row, leaves a marked unattached blob, and the sweep clears it later", :aggregate_failures do
      blob = store.file.blob
      allow(service).to receive(:delete).and_raise(Errno::EIO)

      expect { account.reload.import_upload.remove! }.not_to raise_error
      expect(described_class.count).to eq(0)
      expect(ActiveStorage::Blob.find(blob.id).attachments).to be_empty

      allow(service).to receive(:delete).and_call_original
      travel_to(described_class::ORPHAN_GRACE.from_now + 1.minute) { described_class.sweep! }
      expect([ ActiveStorage::Blob.exists?(blob.id), service.exist?(blob.key) ]).to eq([ false, false ])
    end

    it "logs the class only, never the file", :aggregate_failures do
      store
      allow(service).to receive(:delete).and_raise(Errno::EIO)
      allow(Rails.logger).to receive(:error)

      account.reload.import_upload.remove!

      expect(Rails.logger).to have_received(:error).with(a_string_including("Errno::EIO")).at_least(:once)
    end
  end

  describe ".sweep! (AC-5.4)" do
    def blob(created_at: Time.current, marked: true)
      metadata = { "identified" => true, "analyzed" => true }.merge(marked ? { described_class::MARKER => true } : {})
      ActiveStorage::Blob.create_and_upload!(io: StringIO.new("{}"), filename: "x.json", content_type: "application/json",
        identify: false, metadata:).tap { |created| created.update_columns(created_at:) }
    end

    it "purges expired uploads and old orphans only, and is idempotent", :aggregate_failures do
      expired = store(for_account: create(:user).account).tap { |upload| upload.update!(expires_at: 1.minute.ago) }
      fresh = store(for_account: create(:user).account)
      old_orphan = blob(created_at: 11.minutes.ago)
      kept = [ blob(created_at: 1.minute.ago), blob(created_at: 1.day.ago, marked: false), fresh.file.blob ]
      expired_key = expired.file.blob.key

      2.times { described_class.sweep! }

      expect(described_class.all).to contain_exactly(fresh)
      expect(service.exist?(expired_key)).to be(false)
      expect(ActiveStorage::Blob.exists?(old_orphan.id)).to be(false)
      expect(ActiveStorage::Blob.where(id: kept.map(&:id)).count).to eq(3)
    end

    it "keeps sweeping past an item that fails", :aggregate_failures do
      first = blob(created_at: 20.minutes.ago)
      second = blob(created_at: 20.minutes.ago)
      allow(service).to receive(:delete).and_wrap_original do |original, key|
        key == first.key ? raise(Errno::EIO) : original.call(key)
      end

      expect { described_class.sweep! }.not_to raise_error
      expect(ActiveStorage::Blob.exists?(second.id)).to be(false)
      expect(ActiveStorage::Blob.exists?(first.id)).to be(true) # retried by the next run
    end
  end
end
