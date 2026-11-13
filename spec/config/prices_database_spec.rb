require "rails_helper"

RSpec.describe "the prices database's configuration (spec 081 AC-1.1, AC-2.4)", type: :model do
  def configs(env) = ActiveRecord::DatabaseConfigurations.new(Rails.application.config.database_configuration).configs_for(env_name: env)

  it "names a prices database in every environment, with its own migrations and an SQL schema", :aggregate_failures do
    %w[development test production].each do |env|
      prices = configs(env).find { it.name == "prices" }
      expect(prices&.database).to eq("storage/#{env}_prices.sqlite3"), env
      expect(prices.migrations_paths).to eq("db/prices_migrate"), env
      expect(prices.schema_format).to eq(:sql), env
    end
  end

  it "keeps the other databases' Ruby schema files" do
    others = %w[development test production].flat_map { configs(it) }.reject { it.name == "prices" }
    expect(others.map(&:schema_format).uniq).to eq([ :ruby ])
  end
end
