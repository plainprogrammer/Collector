CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "catalogs" ("id" varchar NOT NULL PRIMARY KEY, "name" varchar NOT NULL, "source_type" varchar NOT NULL, "source_config" json DEFAULT '{}' NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_catalogs_on_source_type" ON "catalogs" ("source_type") /*application='Collector'*/;
CREATE TABLE IF NOT EXISTS "mtg_sets" ("id" varchar NOT NULL PRIMARY KEY, "code" varchar NOT NULL, "name" varchar NOT NULL, "release_date" date, "set_type" varchar, "card_count" integer, "icon_uri" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_mtg_sets_on_code" ON "mtg_sets" ("code") /*application='Collector'*/;
CREATE TABLE IF NOT EXISTS "mtg_cards" ("id" varchar NOT NULL PRIMARY KEY, "mtg_set_id" varchar NOT NULL, "uuid" varchar NOT NULL, "scryfall_id" varchar, "name" varchar NOT NULL, "set_code" varchar NOT NULL, "collector_number" varchar NOT NULL, "rarity" varchar, "mana_cost" varchar, "mana_value" decimal(10,2), "type_line" varchar, "oracle_text" text, "power" varchar, "toughness" varchar, "colors" json DEFAULT '[]', "color_identity" json DEFAULT '[]', "finishes" json DEFAULT '[]', "frame_effects" json DEFAULT '[]', "promo_types" json DEFAULT '[]', "prices" json DEFAULT '{}', "source_data" json DEFAULT '{}', "cached_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_95a95eb1fc"
FOREIGN KEY ("mtg_set_id")
  REFERENCES "mtg_sets" ("id")
);
CREATE INDEX "index_mtg_cards_on_mtg_set_id" ON "mtg_cards" ("mtg_set_id") /*application='Collector'*/;
CREATE UNIQUE INDEX "index_mtg_cards_on_uuid" ON "mtg_cards" ("uuid") /*application='Collector'*/;
CREATE UNIQUE INDEX "index_mtg_cards_on_scryfall_id" ON "mtg_cards" ("scryfall_id") /*application='Collector'*/;
CREATE INDEX "index_mtg_cards_on_name" ON "mtg_cards" ("name") /*application='Collector'*/;
CREATE UNIQUE INDEX "index_mtg_cards_on_set_code_and_collector_number" ON "mtg_cards" ("set_code", "collector_number") /*application='Collector'*/;
CREATE VIRTUAL TABLE mtg_cards_fts USING fts5(
        id UNINDEXED,
        name,
        content='mtg_cards',
        content_rowid='rowid'
      )
/* mtg_cards_fts(id,name) */;
CREATE TABLE IF NOT EXISTS 'mtg_cards_fts_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'mtg_cards_fts_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'mtg_cards_fts_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'mtg_cards_fts_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE TRIGGER mtg_cards_fts_insert AFTER INSERT ON mtg_cards BEGIN
        INSERT INTO mtg_cards_fts(rowid, id, name) VALUES (new.rowid, new.id, new.name);
      END;
CREATE TRIGGER mtg_cards_fts_delete AFTER DELETE ON mtg_cards BEGIN
        INSERT INTO mtg_cards_fts(mtg_cards_fts, rowid, id, name) VALUES('delete', old.rowid, old.id, old.name);
      END;
CREATE TRIGGER mtg_cards_fts_update AFTER UPDATE ON mtg_cards BEGIN
        INSERT INTO mtg_cards_fts(mtg_cards_fts, rowid, id, name) VALUES('delete', old.rowid, old.id, old.name);
        INSERT INTO mtg_cards_fts(rowid, id, name) VALUES (new.rowid, new.id, new.name);
      END;
CREATE TABLE IF NOT EXISTS "collections" ("id" varchar NOT NULL PRIMARY KEY, "name" varchar NOT NULL, "description" text, "item_type" varchar NOT NULL, "catalog_id" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_afd779aeed"
FOREIGN KEY ("catalog_id")
  REFERENCES "catalogs" ("id")
);
CREATE UNIQUE INDEX "index_collections_on_catalog_id" ON "collections" ("catalog_id") /*application='Collector'*/;
CREATE TABLE IF NOT EXISTS "storage_units" ("id" varchar NOT NULL PRIMARY KEY, "name" varchar NOT NULL, "unit_type" varchar NOT NULL, "notes" text, "parent_id" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_df2dea7c70"
FOREIGN KEY ("parent_id")
  REFERENCES "storage_units" ("id")
);
CREATE INDEX "index_storage_units_on_parent_id" ON "storage_units" ("parent_id") /*application='Collector'*/;
CREATE TABLE IF NOT EXISTS "collection_storage_units" ("id" varchar NOT NULL PRIMARY KEY, "collection_id" varchar NOT NULL, "storage_unit_id" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c403081775"
FOREIGN KEY ("collection_id")
  REFERENCES "collections" ("id")
, CONSTRAINT "fk_rails_b0dac6a5fd"
FOREIGN KEY ("storage_unit_id")
  REFERENCES "storage_units" ("id")
);
CREATE UNIQUE INDEX "index_csu_on_collection_and_storage_unit" ON "collection_storage_units" ("collection_id", "storage_unit_id") /*application='Collector'*/;
CREATE TABLE IF NOT EXISTS "items" ("id" varchar NOT NULL PRIMARY KEY, "collection_id" varchar NOT NULL, "storage_unit_id" varchar, "catalog_entry_type" varchar NOT NULL, "catalog_entry_id" varchar NOT NULL, "detail_type" varchar NOT NULL, "detail_id" varchar NOT NULL, "quantity" integer DEFAULT 1 NOT NULL, "acquisition_price" decimal(10,2), "acquisition_date" date, "notes" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_2a18ad62a0"
FOREIGN KEY ("collection_id")
  REFERENCES "collections" ("id")
, CONSTRAINT "fk_rails_3fb4277d6e"
FOREIGN KEY ("storage_unit_id")
  REFERENCES "storage_units" ("id")
);
CREATE INDEX "index_items_on_collection_id" ON "items" ("collection_id") /*application='Collector'*/;
CREATE INDEX "index_items_on_storage_unit_id" ON "items" ("storage_unit_id") /*application='Collector'*/;
CREATE INDEX "index_items_on_catalog_entry_type_and_catalog_entry_id" ON "items" ("catalog_entry_type", "catalog_entry_id") /*application='Collector'*/;
CREATE UNIQUE INDEX "index_items_on_detail_type_and_detail_id" ON "items" ("detail_type", "detail_id") /*application='Collector'*/;
CREATE TABLE IF NOT EXISTS "mtg_card_item_details" ("id" varchar NOT NULL PRIMARY KEY, "condition" varchar DEFAULT 'NM' NOT NULL, "finish" varchar DEFAULT 'nonfoil' NOT NULL, "language" varchar DEFAULT 'EN' NOT NULL, "signed" boolean DEFAULT FALSE NOT NULL, "altered" boolean DEFAULT FALSE NOT NULL, "graded" boolean DEFAULT FALSE NOT NULL, "grading_service" varchar, "grade" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
INSERT INTO "schema_migrations" (version) VALUES
('20251228142210'),
('20251228142032'),
('20251228141821'),
('20251228141622'),
('20251228141413'),
('20251228063530'),
('20251228063156'),
('20251228062826'),
('20251228023348');

