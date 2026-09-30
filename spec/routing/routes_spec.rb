require "rails_helper"

RSpec.describe "Routes", type: :routing do
  it "routes the catalog pages by external key", :aggregate_failures do
    expect(get: "/catalog/entries").to route_to("catalog/entries#index")
    expect(get: "/catalog/entries/abc").to route_to("catalog/entries#show", external_key: "abc")
    expect(get: "/catalog/identities/abc").to route_to("catalog/identities#show", external_key: "abc")
  end

  it "routes sign-in, sign-out and the collection", :aggregate_failures do
    expect(get: "/session/new").to route_to("sessions#new")
    expect(post: "/session").to route_to("sessions#create")
    expect(delete: "/session").to route_to("sessions#destroy")
    expect(get: "/collection").to route_to("collections#show")
  end
end
