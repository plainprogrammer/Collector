require "rails_helper"

RSpec.describe CollectionTable::SelectionState, type: :model do
  let(:user) { create(:user) }
  let(:selection) { BulkSelection.for(user.sessions.create!) }

  def table(query: "", page: nil)
    CollectionTable.new(account: user.account, query:, page:, sort: CollectionTable::Sort.parse(nil, nil))
  end

  it "reports ticked rows and the copies selected off this page", :aggregate_failures do
    stub_const("CollectionTable::PER_PAGE", 1)
    first = owned_printing("Card A", account: user.account, quantity: 2)
    second = owned_printing("Card B", account: user.account, quantity: 5)
    selection.record!(shown_ids: [ first.id, second.id ], ticked_ids: [ first.id, second.id ], header_rendered: false, header_ticked: false)
    state = described_class.new(table: table, selection:)
    expect([ state.selected?(first), state.copies, state.copies_off_page, state.all? ]).to eq([ true, 7, 5, false ])
  end

  it "shows a selection made under another filter as nothing", :aggregate_failures do
    lot = owned_printing(account: user.account)
    selection.record!(shown_ids: [ lot.id ], ticked_ids: [ lot.id ], header_rendered: false, header_ticked: false)
    state = described_class.new(table: table(query: "bolt"), selection:)
    expect([ state.selected?(lot), state.copies, state.copies_off_page ]).to eq([ false, 0, 0 ])
  end
end
