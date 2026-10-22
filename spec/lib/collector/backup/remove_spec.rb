require "rails_helper"

RSpec.describe Collector::Backup, ".remove", :backup do
  let(:file) { scratch("volume").join("collector-restore.partial") }
  let(:sidecars) { %w[-journal -wal -shm].map { |suffix| Pathname("#{file}#{suffix}") } }

  before { [ file, *sidecars ].each { it.write("x") } }

  it "removes the file and all of SQLite's sidecars by default, for the files backup:create makes" do
    described_class.remove(file)

    expect([ file, *sidecars ]).to all(satisfy { !it.exist? })
  end

  it "removes only the file and the suffixes it is given (FR-6: backup:restore's file and its -journal)", :aggregate_failures do
    described_class.remove(file, Collector::Backup::Restore::RESTORE_SUFFIXES)

    expect([ file, sidecars.first ]).to all(satisfy { !it.exist? })
    expect(sidecars.drop(1)).to all(exist)
  end
end
