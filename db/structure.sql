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
INSERT INTO "schema_migrations" (version) VALUES
('20251228063530'),
('20251228063156'),
('20251228062826'),
('20251228023348');

