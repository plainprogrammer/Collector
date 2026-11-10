# Implementation Plan: Store Each Card's Mana Value from the Catalog

**Spec:** docs/specs/058-mtg-mana-value/spec.md (v1.0.2, approved by the maintainer 2026-11-10, Gate A)
**Decisions:** none new; no ADR (spec decision 5 and Non-Goals)
**Created:** 2026-11-10
**Revised:** 2026-11-10 after the Opus plan review (REVISE: two blocking and nine smaller findings, all folded in: the AC-3.2 and AC-3.5 examples reset the identity digests as a real upgrade has them, the redo command is `db:migrate:redo:primary` for this four-database app, the fixture paths are absolute, and the failing-first list is exact)

## Global Constraints

Copied from the spec; every phase includes them.

- **One column, MTG only (decision 1):** `mtg_cards.mana_value`, `float`, nullable, no default. No core table (`catalog_identities`, `catalog_entries`, `catalog_sets`, `catalog_names`) changes, and no core file names the attribute (`spec/*_core_spec.rb` guards read whole files, comments included).
- **Mapper reading (decision 2):** top-level `cmc`, else the front face's (`Array(card["card_faces"]).first&.dig("cmc")`), else `nil`; kept only when `Numeric`, as `to_f`; **never `Float(value)` and never `fetch`** (a raise makes the record `Malformed` and the refresh drops the card); the extension hash always carries the `mana_value` key.
- **Fill (decision 3):** the new key changes every identity's content digest, so the next applied refresh rewrites every card; `MTG::Scryfall::Source#reapply?` is true when spec 011's artwork test **or** "cards exist and none has a mana value" holds. `Catalog::Refresh`, `Catalog::Sources`, views, helpers and controllers are untouched (FR-4).
- **Migration (decision 4):** one reversible migration, no model reference, no backfill; the upgrade proof compares columns both databases have, so `script/upgrade/expected_changes.yml` is unchanged. Prove reversibility with `db:migrate:redo:primary`, never `db:rollback`; after any `db:migrate`, restore the cable, cache and queue schema files.
- **Export format (decision 5):** untouched; `ExportFormat::Rules::VERSIONS` stays `[1, 2, 3]`.
- **Repository rules:** run Ruby through `script/worktree/with_mise` (this shell's `ruby` is system 2.6): `script/worktree/with_mise bin/rspec …`; Conventional Commits, one per step, one git operation per shell call, each ending with `the attribution line the session's system reminder gives`; no real HTTP in the suite (WebMock and VCR); tag spec types explicitly (`type: :model`), multi-expectation examples use `:aggregate_failures`; documents are verified by reading, never by RSpec (`.claude/rules/testing.md`); comments are YARD Markdown with no stray braces, written by `.claude/rules/code-documentation.md`; never read `.kamal/secrets`, `config/master.key`, `.env*` or `storage/`; never two test runs at once in this worktree (shared test database); a full `bin/ci` needs the coordinator's slot.

---

## Goal

After the next catalog refresh, every Magic card in `mtg_cards` carries Scryfall's mana value (halves and reversible cards included), on an instance that upgrades unattended, and nothing else in the app changes.

## Pre-Implementation Gates

- **Simplicity:** one migration, one mapper function, one hook change, one factory, specs and docs; no new component. Pass.
- **Anti-abstraction:** the column is read and written through Active Record and the existing extension hash; no wrapper, no value object. Pass.
- **Integration-first:** Phase 1 and Phase 3 write their failing examples before any code; Phase 3's examples run the real `Catalog::Refresh` against stubbed bulk data. Pass.

**Notes found while planning (not decisions):** the migration uses `change` with `if_not_exists: true` on `add_column`: SQLite copies the table to remove a column, which with foreign keys enforced would cascade into tables that point at the copied one (see `AddLocationToLots`), but nothing points at `mtg_cards` (it only points at `catalog_identities`), so the `down` is safe without `disable_ddl_transaction!`. The existing spec 011 example in `spec/models/mtg/scryfall/source_spec.rb` creates only an `MTG::Printing` (the printing factory builds a `Catalog::Identity`, never an `MTG::Card`), so `MTG::Card.exists?` stays false there and it passes unchanged.

---

## Phase 1: The column

**Implements:** FR-1 | **Satisfies:** AC-1.1, AC-1.2, AC-1.3, AC-1.4, AC-1.5
**Files:** `spec/factories/catalog.rb` (add `:mtg_card`), `spec/models/mtg/card_spec.rb` (new), `db/migrate/20261110100001_add_mana_value_to_mtg_cards.rb` (new), `db/schema.rb` (generated)
**Interfaces:** Consumes: nothing. Produces: `MTG::Card#mana_value` (nullable `Float`); FactoryBot `:mtg_card` (`create(:mtg_card, mana_value: 0.5)`).

- [ ] **Step 1: add the factory.** In `spec/factories/catalog.rb`, after the `:mtg_printing` factory:

```ruby
  factory :mtg_card, class: "MTG::Card" do
    identity factory: :catalog_identity
  end
```

- [ ] **Step 2: write the failing spec** `spec/models/mtg/card_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe MTG::Card, type: :model do
  describe "#mana_value (spec 058)" do
    it "is a nullable float with no default, and a card made without one has none", :aggregate_failures do
      column = described_class.columns_hash.fetch("mana_value")

      expect(column).to have_attributes(type: :float, null: true, default: nil)
      expect(create(:mtg_card).reload.mana_value).to be_nil
    end

    it "keeps zero, a half and a very large value exactly, zero staying zero and not nil" do
      [ 0.0, 0.5, 1_000_000.0 ].each { |value| create(:mtg_card, mana_value: value) }

      expect(described_class.order(:mana_value).pluck(:mana_value)).to eq([ 0.0, 0.5, 1_000_000.0 ])
    end
  end
end
```

- [ ] **Step 3: run it and see it fail.** `script/worktree/with_mise bin/rspec spec/models/mtg/card_spec.rb`. Expected: 2 examples, 2 failures (`KeyError`/`NoMethodError` for `mana_value`).

- [ ] **Step 4: write the migration** `db/migrate/20261110100001_add_mana_value_to_mtg_cards.rb` (the version sorts after the newest, `20261109200002`; rename it if `main` has a newer one when you merge):

```ruby
# A card's mana value, Scryfall's cmc (spec 058 decision 1). Nullable: an existing row has none until the next catalog
# refresh fills it (MTG::Scryfall::Source#reapply?), and a card the source gives no value stays NULL, which is not zero.
# A float because the values are whole numbers or halves, exact in a double, and a later sum or average needs no
# conversion. Reversible: SQLite copies the table to
# remove the column, which is safe here because no foreign key points at mtg_cards (it only points at
# catalog_identities), unlike the tables AddLocationToLots had to protect.
class AddManaValueToMtgCards < ActiveRecord::Migration[8.1]
  def change
    add_column :mtg_cards, :mana_value, :float, if_not_exists: true
  end
end
```

- [ ] **Step 5: migrate and restore the noise.** `script/worktree/with_mise bin/rails db:migrate`, then `git checkout -- db/cable_schema.rb db/cache_schema.rb db/queue_schema.rb` (`.claude/memory/migrate-schema-noise.md`). Expected: `git diff db/schema.rb` is the version line (`2026_11_10_100001`) and one line, `t.float "mana_value"`, in `mtg_cards`.

- [ ] **Step 6: run it and see it pass.** `script/worktree/with_mise bin/rspec spec/models/mtg/card_spec.rb`. Expected: 2 examples, 0 failures.

- [ ] **Step 7: prove reversibility (AC-1.3).** `script/worktree/with_mise bin/rails db:migrate:redo:primary`, restore the three noise files again, then `git diff --stat db/schema.rb`. Expected: no error, and the diff is the same as in Step 5. This app has four databases, so plain `db:migrate:redo` aborts ("You're using a multiple database application"); the `:primary` task is AC-1.3's command here, and `verification.md` says so. Record the output for `verification.md`.

- [ ] **Step 8: guards (AC-1.4, AC-1.5).** `script/worktree/with_mise ruby script/upgrade/guard.rb` (expected: passes), and `script/worktree/with_mise bin/rspec spec/admin_catalog_core_spec.rb spec/footer_core_spec.rb spec/scanner_sitting_core_spec.rb spec/number_entry_core_spec.rb spec/import_apply_core_spec.rb spec/backup_guards_spec.rb` (expected: green). `git diff --stat script/upgrade/expected_changes.yml` is empty.

- [ ] **Step 9: commit.** Stage the four files, then `feat(catalog): add mtg_cards.mana_value (#250)` with the attribution line.

---

## Phase 2: The mapper reads `cmc`

**Implements:** FR-2 | **Satisfies:** AC-2.1, AC-2.2, AC-2.3, AC-2.4, AC-2.5, AC-2.6, AC-2.7
**Files:** `spec/fixtures/files/scryfall/{lightning_bolt_m10,little_girl_unh,gleemax_unh,avatar_token_tm10,ajani_reversible_sld}.json` (new), `spec/support/scryfall_helpers.rb`, `spec/models/mtg/scryfall/mapper_spec.rb`, `app/models/mtg/scryfall/mapper.rb`
**Interfaces:** Consumes: `MTG::Card#mana_value` is not needed here; the mapper only builds records. Produces: `MTG::Scryfall::Mapper.mana_value(card)` returning a `Float` or `nil`; `record.identity.extension[:mana_value]` always present.

- [ ] **Step 1: record the fixtures.** The five objects were fetched from `api.scryfall.com` on 2026-11-10 and are in `/private/tmp/claude-501/-Users-james-orca-workspaces-Collector-mtg-mana-value/1d31e75a-c94c-4b1f-9012-132330d54452/scratchpad/scryfall/` (lightning_bolt_m10.json, little_girl_unh.json, gleemax_unh.json are whole card objects; `ajani_search.json` and `token_search.json` are search lists whose first `data` entry is the Ajani Goldmane reversible card `9cd6a16f-1eff-4624-8f7f-4d9e70a694bb` and the Avatar token `160c268c-db2f-4105-8f40-0237b59ed333`). If that directory is missing (another session's scratchpad), fetch them again with `curl -s -A 'Collector/1.0 (+https://github.com/plainprogrammer/Collector)' -H 'Accept: application/json'` from `https://api.scryfall.com/cards/named?exact=Lightning+Bolt&set=m10`, `…exact=Little+Girl&set=unh`, `…exact=Gleemax&set=unh`, `…/cards/search?q=layout%3Areversible_card+name%3A%22Ajani+Goldmane%22&unique=prints` and `…/cards/search?q=t%3Atoken+set%3Atm10&unique=prints`, pausing 0.3 s between requests (a read-only GET; no data is sent). Write them whole and pretty-printed, one object per file:

```sh
script/worktree/with_mise ruby -rjson -e '
  from, to = ARGV
  read = ->(name) { JSON.parse(File.read("#{from}/#{name}.json")) }
  first = ->(name) { read.(name).fetch("data").first }
  { "lightning_bolt_m10" => read.("lightning_bolt_m10"), "little_girl_unh" => read.("little_girl_unh"),
    "gleemax_unh" => read.("gleemax_unh"), "ajani_reversible_sld" => first.("ajani_search"),
    "avatar_token_tm10" => first.("token_search") }
    .each { |name, card| File.write("#{to}/#{name}.json", JSON.pretty_generate(card) + "\n") }
' /private/tmp/claude-501/-Users-james-orca-workspaces-Collector-mtg-mana-value/1d31e75a-c94c-4b1f-9012-132330d54452/scratchpad/scryfall spec/fixtures/files/scryfall
```

  Check: `ls spec/fixtures/files/scryfall` lists the five new files and the existing `azusa_ja_transform.json`; the reversible card has no top-level `"cmc"` and the others carry `1.0`, `0.5`, `1000000.0` and `0.0`.

- [ ] **Step 2: give the shared helper a `cmc`.** In `spec/support/scryfall_helpers.rb`, `scryfall_card`'s hash gains `"cmc" => 1.0,` after `"mana_cost" => "{R}",` (the line ending `"type_line" => "Instant", …` stays as it is):

```ruby
      "mana_cost" => "{R}", "cmc" => 1.0, "type_line" => "Instant", "oracle_text" => "Lightning Bolt deals 3 damage to any target.",
```

- [ ] **Step 3: write the failing examples.** In `spec/models/mtg/scryfall/mapper_spec.rb`, inside `RSpec.describe MTG::Scryfall::Mapper`, add after the `.entry_record` describe:

```ruby
  describe "mana value (spec 058)" do
    def scryfall_fixture(name) = JSON.parse(file_fixture("scryfall/#{name}.json").read)
    def identity_extension(card) = described_class.entry_record(card).identity.extension

    it "reads a whole mana value, a half and a very large one from recorded cards", :aggregate_failures do
      expect(identity_extension(scryfall_fixture("lightning_bolt_m10"))[:mana_value]).to eq(1.0)
      expect(identity_extension(scryfall_fixture("little_girl_unh"))[:mana_value]).to eq(0.5)
      expect(identity_extension(scryfall_fixture("gleemax_unh"))[:mana_value]).to eq(1_000_000.0)
    end

    it "keeps a token's zero as zero, not nil", :aggregate_failures do
      record = described_class.entry_record(scryfall_fixture("avatar_token_tm10"))

      expect(record.kind).to eq("token")
      expect(record.identity.extension[:mana_value]).to eq(0.0)
    end

    it "reads a reversible card's front face when the card has no cmc of its own, and does not drop it", :aggregate_failures do
      card = scryfall_fixture("ajani_reversible_sld")

      expect(card).not_to have_key("cmc")
      expect(card["card_faces"].map { |face| face["cmc"] }).to eq([ 4.0, 4.0 ])
      expect { described_class.entry_record(card) }.not_to raise_error
      expect(identity_extension(card)[:mana_value]).to eq(4.0)
    end

    it "gives nil, still mapped and with the key present, when no usable cmc exists", :aggregate_failures do
      no_cmc = scryfall_card.except("cmc")
      no_faces_at_all = scryfall_fixture("lightning_bolt_m10").except("cmc", "card_faces")
      reversible = scryfall_fixture("ajani_reversible_sld")
      front_without = reversible.merge("card_faces" => [ reversible["card_faces"][0].except("cmc"), reversible["card_faces"][1] ])

      [ no_cmc, no_faces_at_all, front_without,
        scryfall_card("cmc" => "x"), scryfall_card("cmc" => "3"), scryfall_card("cmc" => true), scryfall_card("cmc" => nil) ].each do |card|
        extension = identity_extension(card)

        expect(extension).to have_key(:mana_value)
        expect(extension[:mana_value]).to be_nil
      end
    end

    it "makes an integer 3 and a float 3.0 one value with one digest", :aggregate_failures do
      integer = described_class.entry_record(scryfall_card("cmc" => 3)).identity
      float = described_class.entry_record(scryfall_card("cmc" => 3.0)).identity

      expect(integer.extension[:mana_value]).to eql(3.0)
      expect(integer.digest).to eq(float.digest)
    end
  end
```

- [ ] **Step 4: run them and see them fail.** `script/worktree/with_mise bin/rspec spec/models/mtg/scryfall/mapper_spec.rb`. Expected: the five new examples fail (`mana_value` absent from the extension); the existing examples pass (AC-2.7).

- [ ] **Step 5: implement.** In `app/models/mtg/scryfall/mapper.rb`, in `identity_record`'s extension hash add `mana_value: mana_value(card),` right after `mana_cost:`'s line, so the block reads:

```ruby
      extension: {
        mana_cost: joined(card, faces, "mana_cost"), mana_value: mana_value(card), type_line: joined(card, faces, "type_line"),
        oracle_text: joined(card, faces, "oracle_text"),
        colors: Array(card["colors"] || card["card_faces"]&.flat_map { |face| Array(face["colors"]) }).uniq.sort,
        color_identity: card.fetch("color_identity").sort, keywords: card.fetch("keywords").sort
      }
```

  and add, after `illustration_id`:

```ruby
  # A card's mana value: Scryfall's cmc, a whole number or a half, as a Float (spec 058 decision 2). A reversible card has
  # no cmc of its own, only one on each face, so the front face's is read, the way illustration_id reads the front face's
  # artwork. Never fetch, and never Float(value): both raise on a missing or odd value, and a raise makes the record
  # Malformed, which silently drops the card from the catalog. A value that isn't a number reads as nil, which is not zero
  # (a land's 0.0 is a value). Always put in the extension, nil included: the refresh's upsert needs the same keys in every
  # row of a batch.
  #
  # @param card [Hash] a Scryfall card object
  # @return [Float, nil]
  def mana_value(card)
    value = card["cmc"] || Array(card["card_faces"]).first&.dig("cmc")
    value.to_f if value.is_a?(Numeric)
  end
```

- [ ] **Step 6: run them and see them pass.** `script/worktree/with_mise bin/rspec spec/models/mtg/scryfall/mapper_spec.rb spec/models/catalog/refresh_scryfall_spec.rb`. Expected: 0 failures.

- [ ] **Step 7: lint and commit.** `script/worktree/with_mise bin/rubocop -a app/models/mtg/scryfall/mapper.rb spec/models/mtg/scryfall/mapper_spec.rb spec/support/scryfall_helpers.rb`, stage the fixtures, helper, mapper and spec, then `feat(mtg): map Scryfall's cmc to a card's mana value (#250)` with the attribution line.

---

## Phase 3: A refresh fills existing cards; an upgraded instance applies once more

**Implements:** FR-3 | **Satisfies:** AC-3.1, AC-3.2, AC-3.3, AC-3.4, AC-3.5, AC-3.6, AC-3.7, AC-3.8
**Files:** `spec/models/mtg/scryfall/source_spec.rb`, `spec/models/catalog/refresh_scryfall_spec.rb`, `app/models/mtg/scryfall/source.rb`
**Interfaces:** Consumes: Phase 1's column and `:mtg_card` factory; Phase 2's mapper and fixtures. Produces: `MTG::Scryfall::Source#reapply?` true for either reason.

- [ ] **Step 1: write the failing hook examples.** In `spec/models/mtg/scryfall/source_spec.rb`, replace the existing `describe "#reapply?"` block with this (the first example is spec 011's, unchanged):

```ruby
  describe "#reapply?" do
    it "asks once for a catalog whose printings have no artwork ids yet (spec 011 AC-2.3)", :aggregate_failures do
      expect(source.reapply?).to be(false) # an empty catalog applies anyway
      printing = create(:mtg_printing)
      expect(source.reapply?).to be(true)
      printing.update!(illustration_id: "art-1")
      expect(source.reapply?).to be(false)
    end

    it "asks once for a catalog whose cards have no mana value yet, when artwork ids are all there (spec 058 AC-3.4)", :aggregate_failures do
      create(:mtg_printing, illustration_id: "art-1")
      card = create(:mtg_card)
      expect(source.reapply?).to be(true)
      card.update!(mana_value: 0.0) # zero is a value
      expect(source.reapply?).to be(false)
    end

    it "does not ask while some card has a mana value, though others lack one, as a few cards legitimately have none", :aggregate_failures do
      create(:mtg_printing, illustration_id: "art-1")
      create(:mtg_card, mana_value: 2.0)
      create(:mtg_card)

      expect(source.reapply?).to be(false)
    end

    it "asks for either reason alone", :aggregate_failures do
      create(:mtg_card, mana_value: 1.0) # mana values present, artwork ids missing
      printing = create(:mtg_printing)
      expect(source.reapply?).to be(true)
      printing.update!(illustration_id: "art-1")
      expect(source.reapply?).to be(false)
    end
  end
```

- [ ] **Step 2: write the failing refresh examples.** In `spec/models/catalog/refresh_scryfall_spec.rb`, add inside the top `RSpec.describe` (after the `"ingests English paper printings"` example; the file already defines `source`, `refresh` (a manual run), `after { FileUtils.rm_rf … }` and `cards`):

```ruby
  describe "mana values (spec 058)" do
    def card_with_art(id, oracle, overrides = {})
      scryfall_card({ "id" => id, "oracle_id" => oracle, "illustration_id" => "art-#{id}", "name" => "Card #{id}" }.merge(overrides))
    end

    def apply(trigger) = described_class.new("mtg", trigger:, source:).call

    # An instance as it was before the upgrade: cards with no mana value and identity digests of the old shape (a real
    # upgraded instance holds digests computed without the key, which is what makes the refresh rewrite each card). Only
    # a spec does this; update_all skips validations and callbacks on purpose.
    def become_pre_upgrade
      MTG::Card.update_all(mana_value: nil)
      Catalog::Identity.update_all(content_digest: "before-058")
    end

    let(:file_cards) { [ card_with_art("a", "oracle-a", "cmc" => 2.0), card_with_art("b", "oracle-b", "cmc" => 0.5) ] }

    it "fills cards that had no mana value, leaving their entries and ids as they were", :aggregate_failures do
      stub_scryfall(cards: file_cards.map { |card| card.except("cmc") })
      refresh
      entry_ids = Catalog::Entry.order(:external_key).pluck(:id)
      expect(MTG::Card.pluck(:mana_value)).to eq([ nil, nil ])

      stub_scryfall(cards: file_cards, stamp: "20260930090555")
      refresh

      expect(MTG::Card.joins(:identity).order("catalog_identities.external_key").pluck(:mana_value)).to eq([ 2.0, 0.5 ])
      expect(Catalog::Entry.order(:external_key).pluck(:id)).to eq(entry_ids)
      expect(MTG::Card.count).to eq(2)
    end

    it "applies a scheduled refresh of an already-applied version while no card has a mana value (AC-3.2)", :aggregate_failures do
      stub_scryfall(cards: file_cards)
      refresh
      become_pre_upgrade
      expect(source.reapply?).to be(true)

      run = apply("scheduled")

      expect(run.status).to eq("applied")
      expect(MTG::Card.pluck(:mana_value)).to match_array([ 2.0, 0.5 ])
    end

    it "skips a scheduled refresh of an already-applied version once a card has a mana value (AC-3.3)", :aggregate_failures do
      stub_scryfall(cards: file_cards)
      refresh

      run = apply("scheduled")

      expect(run.status).to eq("skipped")
      expect(run.message).to include("already applied")
    end

    it "applies a manual refresh of an already-applied version as always, and fills the column (AC-3.5)", :aggregate_failures do
      stub_scryfall(cards: file_cards)
      refresh
      become_pre_upgrade

      expect(apply("manual").status).to eq("applied")
      expect(MTG::Card.pluck(:mana_value)).to match_array([ 2.0, 0.5 ])
    end

    it "changes nothing the second time over the same file (AC-3.6)", :aggregate_failures do
      stub_scryfall(cards: file_cards)
      refresh
      cards_before = MTG::Card.order(:id).pluck(:id, :mana_value, :updated_at)

      second = described_class.new("mtg", trigger: "manual", source:)
      second.call

      expect(MTG::Card.order(:id).pluck(:id, :mana_value, :updated_at)).to eq(cards_before)
      expect(second.made_progress?).to be(false)
    end

    it "writes a reversible card with its front face's value and counts no malformed record (AC-3.7)", :aggregate_failures do
      reversible = JSON.parse(file_fixture("scryfall/ajani_reversible_sld.json").read)
      stub_scryfall(cards: [ reversible ], sets: [ scryfall_set("code" => reversible.fetch("set"), "name" => reversible.fetch("set_name")) ])

      run = refresh

      expect(run.malformed_count).to eq(0)
      expect(Catalog::Entry.pluck(:external_key)).to eq([ reversible.fetch("id") ])
      expect(MTG::Card.pluck(:mana_value)).to eq([ 4.0 ])
    end
  end
```

- [ ] **Step 3: run them and see them fail.** `script/worktree/with_mise bin/rspec spec/models/mtg/scryfall/source_spec.rb spec/models/catalog/refresh_scryfall_spec.rb`. Expected failures: the second hook example ("asks once for a catalog whose cards have no mana value yet") and the AC-3.2 example (no mana-value reason yet; its run is `skipped`). Everything else already passes and is a guard: the spec 011 hook example, the third and fourth hook examples (the third is `false` and the fourth is decided by the artwork test alone before the change), and the refresh examples for AC-3.1, AC-3.3, AC-3.5, AC-3.6 and AC-3.7 (the Phase 2 mapper fills the column through the digest). Record in the commit body which two failed first and that the others are guards.

- [ ] **Step 4: implement.** In `app/models/mtg/scryfall/source.rb` replace the `#reapply?` comment and line:

```ruby
  # Whether an already-applied bulk file is worth applying again (Catalog::Refresh asks once, before the skip; a manual
  # refresh applies anyway). Two reasons, either alone is enough:
  #
  # - Spec 011 AC-2.3: an instance upgrading to artwork ids applies its current file once more, art matching on or off, so
  #   every printing gets its artwork id. About 760 printings legitimately have none, so "any without" isn't the test.
  # - Spec 058 decision 3: an instance upgrading to mana values does the same, so its cards fill on the next refresh even
  #   when Scryfall has published no new file. A few cards may have no value, so the test is that none has one.
  #
  # Both are false on an empty catalog (it applies anyway) and once one row has the value, so an up-to-date catalog skips as
  # before. Two `exists?` queries a scheduled run.
  #
  # @return [Boolean]
  def reapply? = artwork_ids_missing? || mana_values_missing?
```

  and at the top of the `private` section (before `def fetch`), add:

```ruby
    def artwork_ids_missing? = MTG::Printing.exists? && !MTG::Printing.where.not(illustration_id: nil).exists?

    def mana_values_missing? = MTG::Card.exists? && !MTG::Card.where.not(mana_value: nil).exists?
```

- [ ] **Step 5: run them and see them pass.** `script/worktree/with_mise bin/rspec spec/models/mtg/scryfall/source_spec.rb spec/models/catalog/refresh_scryfall_spec.rb spec/models/catalog/refresh_spec.rb spec/models/catalog/refresh_operation_spec.rb`. Expected: 0 failures (the spec 011 and `FakeCatalogSource` examples are unchanged).

- [ ] **Step 6: AC-3.8 and neighbours.** `grep -rn "mana_value" app lib config --include='*.rb' --include='*.erb'` lists the migration-free uses: only `app/models/mtg/scryfall/mapper.rb` and `source.rb` (no view, helper or controller; AC-3.8, FR-4). Then run the catalog and art examples that apply a refresh: `script/worktree/with_mise bin/rspec spec/models/mtg spec/models/catalog spec/jobs spec/requests/admin`. Expected: 0 failures.

- [ ] **Step 7: lint and commit.** `bin/rubocop -a` on the three files, stage them, then `feat(mtg): apply an already-applied file once for cards without a mana value (#250)` with the attribution line and, in the body, the examples that failed first.

---

## Phase 4: The documents

**Implements:** (Story 4 documents) | **Satisfies:** AC-4.1, AC-4.2, AC-4.3, AC-4.4, AC-4.5, AC-4.6
**Files:** `docs/architecture/catalog-core.md`, `docs/architecture/catalog-operations.md`, `docs/releasing.md`, `docs/specs/README.md`, `docs/specs/058-mtg-mana-value/verification.md` (new)
**Interfaces:** Consumes: the code of Phases 1 to 3. Produces: nothing code reads.

Documents are checked by reading, never by RSpec; the area docs say what is true after this change and name its source inline (`.claude/rules/documentation.md`). The distillation step (`distill-feature`) later moves the specs index row's status; this phase only updates the area docs' facts.

- [ ] **Step 1: catalog core.** In `docs/architecture/catalog-core.md`: (a) in the Glossary's **Extension** entry, change "`MTG::Card` holds mana cost, type line and rules text (a multi-face card's faces joined with " // "), colors, color identity and keywords" to "`MTG::Card` holds mana cost, mana value, type line and rules text (…), colors, color identity and keywords", and add after that sentence: "The mana value is Scryfall's `cmc`, a nullable float (a whole number or a half; null is unknown, not zero), read from the card's own `cmc` or, for a reversible card that has none, its front face's, and never worked out from the mana cost, because X, hybrid, Phyrexian, split and adjusted cards need rules Scryfall has already applied (spec 058 decisions 1, 2)."; (b) add to "Decisions not in an ADR": "- **The mana value is Scryfall's number, read without failing.** `MTG::Scryfall::Mapper.mana_value` reads `cmc`, else the front face's, else nothing, and never uses `fetch`: a reversible card has no top-level `cmc`, and a `fetch` would make the record malformed and drop the card from the catalog. Nothing reads the column yet; the deck shape panel ([#256](https://github.com/plainprogrammer/Collector/issues/256)) is its first reader and decides how halves bucket and which faces of a double-faced card count (spec 058 decisions 1, 2, Non-Goals).", and (c) add spec 058 and #250 to Sources: "- [Spec 058](../specs/058-mtg-mana-value/spec.md): decisions 1, 2 (the column and the mapper's reading); issue [#250](https://github.com/plainprogrammer/Collector/issues/250). Its decision 3 is [catalog operations](catalog-operations.md)'."

- [ ] **Step 2: catalog operations.** In `docs/architecture/catalog-operations.md`: (a) in the Refresh's "Running" step (the line that says a scheduled run whose version was already applied ends `skipped`), after "and so does any run whose source's `#reapply?` says so" add "(`MTG::Scryfall::Source#reapply?` says so for two reasons: spec 011 AC-2.3's, printings with no artwork id, and spec 058 decision 3's, cards in the catalog and none with a mana value, so an upgraded instance fills the new column on its next refresh even when Scryfall's file is unchanged; the test is that none has one, not that any lacks one, as for artwork ids)"; (b) to the "**Accepted limits and open issues:**" list, add "- A refresh that fails after some batches committed leaves some cards with a mana value and some without; a scheduled run of the same version is then skipped as already applied (the reapply test needs none to have one), and the rest fill when Scryfall publishes a new file or on a manual refresh; spec 011's artwork test has the same gap (spec 058 Error Scenarios)."; (c) add "[Spec 058](../specs/058-mtg-mana-value/spec.md) decision 3 (`#reapply?`'s second reason)" to Sources.

- [ ] **Step 3: upgrade notes.** In `docs/releasing.md`, "Upgrade notes", add as the newest entry (first bullet): "- **Mana value (spec 058).** One migration, `AddManaValueToMtgCards`, runs on boot; it adds a nullable `mana_value` column to `mtg_cards` and changes nothing else. Existing cards have no mana value until the next catalog refresh, which applies even if Scryfall's file hasn't changed since the last one (the weekly refresh, or **Refresh now** on the admin catalog page, or `bin/rails "catalog:refresh[mtg]"`); nothing reads it yet. Nothing is required of the operator, and the export format is unchanged (version 3)."

- [ ] **Step 4: data portability (AC-4.4) and index (AC-4.5).** Re-read `docs/architecture/data-portability.md` and `docs/export-format/README.md`: no edit. In `docs/specs/README.md`, the 058 row's Status stays "Approved" until `distill-feature` moves it (its row already says what it adds to).

- [ ] **Step 5: write `docs/specs/058-mtg-mana-value/verification.md`** with: the Phase 1 `db:migrate:redo:primary` output and schema diff (AC-1.3); the commands and results of Phase 5 (rspec counts, rubocop, yard, brakeman, guard, `bin/ci`'s run); each AC with the example or the reading that satisfies it; the AC-4.x readings (which line of which document, by quoting its first words); the confirmation for AC-4.4 (data-portability.md's version rule lists only collector-owned tables and columns, and `mtg_cards` is global catalog data; `ExportFormat::Rules::VERSIONS` is `[1, 2, 3]`); and later, under `## Implementation review`, the review's verdict on its first line.

- [ ] **Step 6: commit.** Stage the documents and `docs: spec 058 area docs, upgrade note and verification (#250)` with the attribution line.

---

## Phase 5: Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs
**Files:** none new.
**Interfaces:** Consumes: everything. Produces: the evidence in `verification.md`.

- [ ] **Step 1: the touched specs** (no slot needed): `script/worktree/with_mise bin/rspec spec/models/mtg spec/models/catalog spec/jobs spec/requests/admin spec/requests/catalog`. Expected: 0 failures.
- [ ] **Step 2: lint, security, docs build:** `bin/rubocop`, `bin/brakeman`, `bin/yard doc` (a YARD warning fails it; AC-4.6), `ruby script/upgrade/guard.rb`, each through `script/worktree/with_mise`. Expected: no offenses, no warnings, guard passes.
- [ ] **Step 3: ask the coordinator for the CI slot**, then `script/worktree/with_mise bin/ci` (or `bin/ci checks` and `bin/ci rspec` in turn). Expected: green. Release the slot with the SHA and result. The container upgrade proof (`bin/upgrade-smoke`) and the backup smoke run in GitHub's image job, on the pushed branch; read their result there.
- [ ] **Step 4: restore noise.** `git status` shows only the intended files; `db/cable_schema.rb`, `db/cache_schema.rb` and `db/queue_schema.rb` are unchanged, and `db/schema.rb` holds only the version line and the one column (`git checkout db/schema.rb` after a `bin/ci` run that loaded the queue tables, then check the diff is the intended one).
- [ ] **Step 5: implementation review** (`sdd-review` Mode B, read-only, Opus), its verdict recorded in `verification.md` under `## Implementation review`; then session-wrap and `distill-feature`.

---

## Quickstart Validation

The Phase 3 refresh examples are the check: they run the real `Catalog::Refresh` over stubbed bulk data (no Scryfall request) and show cards filling from NULL to their value, halves and a reversible card included. On a real instance the same is `MTG::Card.where.not(mana_value: nil).count` after the next refresh.
