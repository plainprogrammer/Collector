require "rails_helper"
require Rails.root.join("script/upgrade/households").to_s

# Spec 090 decision 10 and AC-6.5: the two tiers of the check on fixture snapshots, never on the application.
RSpec.describe Upgrade::Households, :upgrade do
  # The three names of AC-1.5, so this check, the model and the backfill agree on the same cases.
  let(:names) { [ "n" * 100, "O'Neil", "é" * 100 ] }

  def snapshot(users:, memberships: nil, households: nil, accounts: nil)
    path = File.join(upgrade_dir, "snap#{SecureRandom.hex(3)}.sqlite3")
    build_database(path) do |db|
      db.execute_batch(<<~SQL)
        CREATE TABLE households (id INTEGER PRIMARY KEY, name TEXT);
        CREATE TABLE memberships (id INTEGER PRIMARY KEY, household_id INTEGER, user_id INTEGER, role TEXT);
        CREATE TABLE accounts (id INTEGER PRIMARY KEY, household_id INTEGER, kind TEXT);
        CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, account_id INTEGER);
      SQL
      users.each_with_index do |name, i|
        id = i + 1
        db.execute("INSERT INTO households VALUES (?, ?)", [ id, "#{name[0, 88]}'s household" ]) unless households == :none
        db.execute("INSERT INTO accounts VALUES (?, ?, 'personal')", [ id, id ])
        db.execute("INSERT INTO users VALUES (?, ?, ?)", [ id, name, id ])
        db.execute("INSERT INTO memberships VALUES (?, ?, ?, 'manager')", [ id, id, id ]) unless memberships == :none
      end
      yield db if block_given?
    end
    open_database(path)
  end

  it "passes a clean snapshot in both tiers (AC-6.1)" do
    expect(described_class.problems(snapshot(users: names), backfill: true)).to be_empty
  end

  it "names a user with no membership (AC-6.5)" do
    expect(described_class.problems(snapshot(users: names, memberships: :none))).to include(a_string_matching(/user .* membership/))
  end

  it "names a household with no manager (AC-6.5)" do
    db = snapshot(users: names) { it.execute("UPDATE memberships SET role = 'member' WHERE id = 1") }
    expect(described_class.problems(db)).to include(a_string_matching(/household 1 .*manager/))
  end

  it "names an account in another user's household (AC-6.5)" do
    db = snapshot(users: names) { it.execute("UPDATE accounts SET household_id = 2 WHERE id = 1") }
    expect(described_class.problems(db)).to include(a_string_matching(/account 1 .*household/))
  end

  it "names an account with no household (AC-6.5)" do
    db = snapshot(users: names) { it.execute("UPDATE accounts SET household_id = NULL WHERE id = 3") }
    expect(described_class.problems(db)).to include(a_string_matching(/account 3 .*no household/))
  end

  it "checks the backfill's facts only when asked: a name that differs, a count that differs, a role or a kind that differs (AC-6.5)", :aggregate_failures do
    renamed = snapshot(users: names) { it.execute("UPDATE households SET name = 'Someone else' WHERE id = 2") }
    expect(described_class.problems(renamed)).to be_empty
    expect(described_class.problems(renamed, backfill: true)).to include(a_string_matching(/name/))
    extra = snapshot(users: names) { it.execute("INSERT INTO households VALUES (9, 'x'); INSERT INTO memberships VALUES (9, 9, 99, 'manager')") }
    expect(described_class.problems(extra, backfill: true)).to include(a_string_matching(/count/))
    member = snapshot(users: names) { it.execute("INSERT INTO memberships VALUES (10, 1, 98, 'member')") }
    expect(described_class.problems(member, backfill: true)).to include(a_string_matching(/role/))
    shared = snapshot(users: names) { it.execute("UPDATE accounts SET kind = 'shared' WHERE id = 1") }
    expect(described_class.problems(shared, backfill: true)).to include(a_string_matching(/kind/))
  end

  it "lets a joined household and a shared account pass tier 1 (it must outlive #381 and #384)" do
    db = snapshot(users: names) do
      it.execute("UPDATE memberships SET household_id = 1, role = 'member' WHERE user_id = 2")
      it.execute("UPDATE accounts SET household_id = 1 WHERE id = 2")
      it.execute("DELETE FROM households WHERE id = 2") # user 2 left its household of one when it joined household 1
      it.execute("INSERT INTO accounts VALUES (10, 1, 'shared')")
    end
    expect(described_class.problems(db)).to be_empty
  end

  it "fails a snapshot with no households table (AC-6.1)" do
    path = File.join(upgrade_dir, "old.sqlite3")
    build_database(path) { it.execute_batch("CREATE TABLE users (id INTEGER PRIMARY KEY)") }
    expect(described_class.problems(open_database(path))).to eq([ "the snapshot has no households or memberships table" ])
  end
end
