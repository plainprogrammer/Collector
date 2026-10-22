require "rails_helper"

RSpec.describe "what a backup holds (spec 030 decisions 2 and 3)", :backup, type: :model do
  let(:transient) { { "ImportUpload" => %i[file] } } # spec 028's stored import file: one hour, restored without its file (ADR 0022)
  let(:advice) do
    "Spec 030 decision 2: decide what a backup does with it, then update that decision's table, docs/backup-restore.md " \
      "and the README's Backup and restore section, and list it here"
  end

  def attachments_of(models)
    models.to_h { [ it.name, it.reflect_on_all_attachments.map(&:name) ] }.reject { |_name, names| names.empty? }
  end

  def unlisted(models)
    attachments_of(models).filter_map { |name, names| [ name, names - transient.fetch(name, []) ] if (names - transient.fetch(name, [])).any? }.to_h
  end

  def application_models
    Rails.application.eager_load!
    ApplicationRecord.descendants.select { it.name && !it.abstract_class? && Object.const_defined?(it.name) }
  end

  it "knows every collector-owned attachment: only ImportUpload's, listed as transient (AC-5.5)" do
    expect(unlisted(application_models)).to be_empty, advice
  end

  it "would notice a new attachment (a negative control for the guard above)" do
    cover = Class.new(ApplicationRecord) do
      self.table_name = "accounts"
      def self.name = "CoverPhotoOwner"
      has_one_attached :photo
    end

    expect(unlisted([ cover ])).to eq("CoverPhotoOwner" => [ :photo ])
  end

  it "knows exactly the four production databases (AC-5.5)" do
    names = ActiveRecord::DatabaseConfigurations.new(Rails.application.config.database_configuration)
      .configs_for(env_name: "production").map(&:name)

    expect(names).to match_array(%w[primary queue cache cable]), advice
  end

  it "uses no Active Record encryption, so no secret protects any data in the database (AC-4.3)", :aggregate_failures do
    encrypting = application_models.select { it.respond_to?(:encrypted_attributes) && it.encrypted_attributes.present? }
    # config.active_record.encryption is not blank under load_defaults 8.1 (the 7.1 defaults set hash_digest_class and
    # support_sha1_for_non_deterministic_encryption), so check what AC-4.3 names: the keys. Credentials are never read here.
    keys = Rails.application.config.active_record.encryption.to_h.slice(:primary_key, :deterministic_key, :key_derivation_salt)
    declaring = Dir[Rails.root.join("app/**/*.rb").to_s].select { File.read(it).match?(/^\s*encrypts\s/) }

    expect(encrypting.map(&:name)).to be_empty,
      "Spec 030 decision 3: a model that encrypts needs the procedure's secrets section and decision 3 to say what the secret then protects"
    expect(declaring).to be_empty
    expect(keys).to be_empty
  end
end
