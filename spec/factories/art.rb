FactoryBot.define do
  factory :mtg_artwork, class: "MTG::Artwork" do
    sequence(:illustration_id) { |n| format("00000000-0000-4000-8000-%012d", n) }
    entry factory: :catalog_entry
    fingerprint { "\x00".b * 128 }
    settings_digest { MTG::Art::Settings.digest }
  end

  factory :mtg_art_build, class: "MTG::ArtBuild" do
    status { "finished" }
    sequence(:job_id) { |n| "job-#{n}" }
    catalog_version { "default-cards-1" }
    settings_digest { MTG::Art::Settings.digest }
    started_at { 1.hour.ago }
    heartbeat_at { 30.minutes.ago }
    finished_at { 30.minutes.ago }
  end
end
