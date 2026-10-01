require "rails_helper"

RSpec.describe "Routes", type: :routing do
  it "routes the catalog pages by external key", :aggregate_failures do
    expect(get: "/catalog/entries").to route_to("catalog/entries#index")
    expect(get: "/catalog/entries/abc").to route_to("catalog/entries#show", external_key: "abc")
    expect(get: "/catalog/identities/abc").to route_to("catalog/identities#show", external_key: "abc")
  end

  it "routes quick add under a printing" do
    expect(post: "/catalog/entries/abc/quick_add").to route_to("catalog/quick_adds#create", entry_external_key: "abc")
  end

  it "routes sign-in, sign-out and the collection", :aggregate_failures do
    expect(get: "/session/new").to route_to("sessions#new")
    expect(post: "/session").to route_to("sessions#create")
    expect(delete: "/session").to route_to("sessions#destroy")
    expect(get: "/collection").to route_to("collections#show")
  end

  it "routes sign-up", :aggregate_failures do
    expect(get: "/registration/new").to route_to("registrations#new")
    expect(post: "/registration").to route_to("registrations#create")
  end

  it "routes the root and the More page", :aggregate_failures do
    expect(get: "/").to route_to("collections#root")
    expect(get: "/more").to route_to("mores#show")
  end

  it "routes user administration", :aggregate_failures do
    expect(get: "/admin/users").to route_to("admin/users#index")
    expect(post: "/admin/users").to route_to("admin/users#create")
    expect(get: "/admin/users/1/edit").to route_to("admin/users#edit", id: "1")
    expect(delete: "/admin/users/1").to route_to("admin/users#destroy", id: "1")
    expect(get: "/admin/users/1/deletion/new").to route_to("admin/users/deletions#new", user_id: "1")
    expect(patch: "/admin/sign_up_setting").to route_to("admin/sign_up_settings#update")
  end

  it "routes adding and managing copies", :aggregate_failures do
    expect(get: "/catalog/entries/abc/lots/new").to route_to("lots#new", entry_external_key: "abc")
    expect(post: "/catalog/entries/abc/lots").to route_to("lots#create", entry_external_key: "abc")
    expect(get: "/lots/1/edit").to route_to("lots#edit", id: "1")
    expect(patch: "/lots/1").to route_to("lots#update", id: "1")
    expect(delete: "/lots/1").to route_to("lots#destroy", id: "1")
    expect(get: "/lots/1/removal/new").to route_to("lots/removals#new", lot_id: "1")
  end

  it "routes bulk mode's selection", :aggregate_failures do
    expect(post: "/collection/selection").to route_to("collections/selections#create")
    expect(patch: "/collection/selection").to route_to("collections/selections#update")
  end

  it "routes Set condition", :aggregate_failures do
    expect(get: "/collection/condition_change/new").to route_to("collections/condition_changes#new")
    expect(post: "/collection/condition_change").to route_to("collections/condition_changes#create")
  end

  it "routes bulk removal and its undo", :aggregate_failures do
    expect(get: "/collection/bulk_removals/new").to route_to("collections/bulk_removals#new")
    expect(post: "/collection/bulk_removals").to route_to("collections/bulk_removals#create")
    expect(post: "/collection/bulk_removals/1/undo").to route_to("collections/bulk_removals/undos#create", bulk_removal_id: "1")
  end

  it "routes the OCR engine's files by version and path" do
    expect(get: "/ocr/v7.0.0/core/tesseract-core-lstm.wasm.js")
      .to route_to("ocr_assets#show", version: "v7.0.0", path: "core/tesseract-core-lstm.wasm.js")
  end

  it "routes the scanner and its readings", :aggregate_failures do
    expect(get: "/scanner").to route_to("scanners#show")
    expect(post: "/scanner/readings").to route_to("scanner/readings#create")
  end
end
