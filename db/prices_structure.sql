CREATE TABLE "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE "price_sources" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar NOT NULL, "name" varchar NOT NULL, "attribution" varchar NOT NULL, "attribution_url" varchar, "hosted_paid_allowed" boolean DEFAULT FALSE NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT price_sources_key_present CHECK (length(trim(key)) >= 1), CONSTRAINT price_sources_name_present CHECK (length(trim(name)) >= 1), CONSTRAINT price_sources_attribution_present CHECK (length(trim(attribution)) >= 1));
CREATE UNIQUE INDEX "index_price_sources_on_key" ON "price_sources" ("key") /*application='Collector'*/;
CREATE TABLE "price_series" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "finish" varchar NOT NULL, "currency" varchar NOT NULL, "kind" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT price_series_currency_code CHECK (currency GLOB '[A-Z][A-Z][A-Z]'));
CREATE UNIQUE INDEX "index_price_series_on_finish_and_currency_and_kind" ON "price_series" ("finish", "currency", "kind") /*application='Collector'*/;
CREATE TABLE "current_prices" ("catalog_entry_id" integer NOT NULL, "price_source_id" integer NOT NULL, "price_series_id" integer NOT NULL, "cents" integer NOT NULL, "reported_on" date NOT NULL, "changed_on" date NOT NULL, PRIMARY KEY ("catalog_entry_id", "price_source_id", "price_series_id"), CONSTRAINT "fk_rails_4152bf1121"
FOREIGN KEY ("price_source_id")
  REFERENCES "price_sources" ("id")
 ON DELETE RESTRICT, CONSTRAINT "fk_rails_a2f042686c"
FOREIGN KEY ("price_series_id")
  REFERENCES "price_series" ("id")
 ON DELETE RESTRICT, CONSTRAINT current_prices_cents_non_negative CHECK (cents >= 0)) WITHOUT ROWID /*application='Collector'*/;
CREATE TABLE "price_changes" ("catalog_entry_id" integer NOT NULL, "price_source_id" integer NOT NULL, "price_series_id" integer NOT NULL, "recorded_on" date NOT NULL, "cents" integer, PRIMARY KEY ("catalog_entry_id", "price_source_id", "price_series_id", "recorded_on"), CONSTRAINT "fk_rails_7436afe6eb"
FOREIGN KEY ("price_source_id")
  REFERENCES "price_sources" ("id")
 ON DELETE RESTRICT, CONSTRAINT "fk_rails_ed874b4cbb"
FOREIGN KEY ("price_series_id")
  REFERENCES "price_series" ("id")
 ON DELETE RESTRICT, CONSTRAINT price_changes_cents_non_negative CHECK (cents IS NULL OR cents >= 0)) WITHOUT ROWID /*application='Collector'*/;
CREATE TABLE "price_refresh_runs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "price_source_id" integer NOT NULL, "run_on" date NOT NULL, "source_version" varchar, "status" varchar NOT NULL, "error" text, "started_at" datetime(6) NOT NULL, "finished_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c95c78b8b6"
FOREIGN KEY ("price_source_id")
  REFERENCES "price_sources" ("id")
 ON DELETE RESTRICT, CONSTRAINT price_refresh_runs_status_known CHECK (status IN ('running', 'finished', 'skipped', 'failed')));
CREATE INDEX "index_price_refresh_runs_on_price_source_id_and_run_on" ON "price_refresh_runs" ("price_source_id", "run_on") /*application='Collector'*/;
INSERT INTO "schema_migrations" (version) VALUES
('20261113100001');

