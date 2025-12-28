class CreateMTGCardsFts < ActiveRecord::Migration[8.1]
  def up
    # Create FTS5 virtual table for full-text search on card names
    execute <<-SQL
      CREATE VIRTUAL TABLE mtg_cards_fts USING fts5(
        id UNINDEXED,
        name,
        content='mtg_cards',
        content_rowid='rowid'
      );
    SQL

    # Create triggers to keep FTS table in sync with mtg_cards
    execute <<-SQL
      CREATE TRIGGER mtg_cards_fts_insert AFTER INSERT ON mtg_cards BEGIN
        INSERT INTO mtg_cards_fts(rowid, id, name) VALUES (new.rowid, new.id, new.name);
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER mtg_cards_fts_delete AFTER DELETE ON mtg_cards BEGIN
        INSERT INTO mtg_cards_fts(mtg_cards_fts, rowid, id, name) VALUES('delete', old.rowid, old.id, old.name);
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER mtg_cards_fts_update AFTER UPDATE ON mtg_cards BEGIN
        INSERT INTO mtg_cards_fts(mtg_cards_fts, rowid, id, name) VALUES('delete', old.rowid, old.id, old.name);
        INSERT INTO mtg_cards_fts(rowid, id, name) VALUES (new.rowid, new.id, new.name);
      END;
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS mtg_cards_fts_update;"
    execute "DROP TRIGGER IF EXISTS mtg_cards_fts_delete;"
    execute "DROP TRIGGER IF EXISTS mtg_cards_fts_insert;"
    execute "DROP TABLE IF EXISTS mtg_cards_fts;"
  end
end
