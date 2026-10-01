require "rails_helper"

RSpec.describe CollectionTable::Sort, type: :model do
  it "reads the default order as Name ascending, so the first Name activation goes descending", :aggregate_failures do
    sort = described_class.parse(nil, nil)
    expect([ sort.default?, sort.key, sort.to_params ]).to eq([ true, "", {} ])
    expect(%w[name set condition quantity price].map { |column| sort.aria_sort(column) }).to eq(%w[ascending none none none none])
    expect(sort.toward("name").to_params).to eq(sort: "name", dir: "desc")
    expect(sort.toward("price").to_params).to eq(sort: "price", dir: "asc")
  end

  it "reverses the sorted column on each activation", :aggregate_failures do
    sort = described_class.parse("price", "desc")
    expect(sort.aria_sort("price")).to eq("descending")
    expect(sort.toward("price").to_params).to eq(sort: "price", dir: "asc")
    expect(sort.toward("price").toward("price").to_params).to eq(sort: "price", dir: "desc")
  end

  it "ignores unknown columns and directions", :aggregate_failures do
    expect(described_class.parse("bogus", "desc")).to be_default
    expect(described_class.parse("price", "sideways").direction).to eq("asc")
    expect(described_class.parse([ "price" ], { "x" => 1 })).to be_default
  end

  it "round-trips through its key", :aggregate_failures do
    expect(described_class.from_key("condition-desc").to_params).to eq(sort: "condition", dir: "desc")
    expect(described_class.from_key("")).to be_default
    expect(described_class.from_key("name").to_params).to eq(sort: "name", dir: "asc")
  end
end
