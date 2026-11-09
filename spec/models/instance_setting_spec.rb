require "rails_helper"

# #229 (from #218 ruling 3): the table holds one row, by construction. The row's id is 1, the database refuses any other
# id, and `current` makes the row race-safely instead of `first || create!`.
RSpec.describe InstanceSetting, type: :model do
  def insert_row(id)
    described_class.connection.execute(
      "INSERT INTO instance_settings (id, sign_up_open, created_at, updated_at) VALUES (#{id.to_i}, 0, '2026-11-09', '2026-11-09')"
    )
  end

  describe "the database guard" do
    it "refuses a second row, however it is inserted", :aggregate_failures do
      described_class.current

      expect { insert_row(2) }.to raise_error(ActiveRecord::StatementInvalid, /CHECK constraint failed/)
      expect { described_class.new.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
      expect(described_class.count).to eq(1)
    end

    it "refuses a first row whose id is not 1" do
      expect { insert_row(7) }.to raise_error(ActiveRecord::StatementInvalid, /CHECK constraint failed/)
    end

    it "refuses a second row with id 1 too (the primary key)" do
      described_class.current

      expect { insert_row(1) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe ".current" do
    it "makes the one row, closed, when the table is empty", :aggregate_failures do
      expect(described_class.count).to eq(0)

      setting = described_class.current

      expect(setting).to have_attributes(id: 1, sign_up_open: false)
      expect(described_class.count).to eq(1)
    end

    it "returns the same row every time and leaves it as it was", :aggregate_failures do
      described_class.current.update!(sign_up_open: true)

      expect(described_class.current.id).to eq(1)
      expect(described_class.current).to be_sign_up_open
      expect(described_class.count).to eq(1)
    end

    it "finds the row another request inserted after this one looked (two first reads at once)", :aggregate_failures do
      # The losing request's first lookup saw an empty table; the winner's row is there by the time it inserts.
      winner = described_class.create!(id: 1, sign_up_open: true)
      allow(described_class).to receive(:find_by).with(id: 1).and_return(nil)

      expect(described_class.current).to eq(winner)
      expect(described_class.count).to eq(1)
      expect(winner.reload).to be_sign_up_open
    end
  end
end
