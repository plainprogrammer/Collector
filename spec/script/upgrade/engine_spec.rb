require "rails_helper"
require Rails.root.join("script/upgrade/engine").to_s

RSpec.describe Upgrade::Engine do
  let(:calls) { [] }
  let(:listing) { "production.sqlite3\nproduction.sqlite3-wal\nproduction_cache.sqlite3\n" }
  let(:executor) do
    lambda do |argv, _stdin|
      calls << argv
      out = if argv.include?("inspect") && argv.include?("image") then "[{}]"
      elsif argv.include?("ls") then listing
      else ""
      end
      Upgrade::Engine::Result.new(out, "", 0)
    end
  end
  let(:engine) { described_class.new(cli: "docker", run_flags: [ "--platform", "linux/arm64" ], executor:) }

  def refused(category, args, **) = engine.send(:run, category, args, **)

  it "builds only commands that a category accepts, for the container's life (AC-8.3)", :aggregate_failures do
    expect do
      engine.pull("img:1", platform: "linux/arm64")
      engine.image_info("img:1")
      engine.create_volume("v")
      engine.start(name: "c", volume: "v", secret: "s", image: "img:1", mounts: [ "/tmp/b:/backups" ])
      engine.port("c")
      engine.state("c")
      engine.logs("c")
      engine.stop("c")
      engine.remove("c")
      engine.remove_volume("v")
    end.not_to raise_error
    expect(calls).to all(start_with("docker"))
  end

  it "builds only commands that a category accepts, for the tasks and the files (AC-8.3)", :aggregate_failures do
    expect do
      engine.runner("c", "puts 1")
      engine.tasks("c")
      engine.task("c", "backup:create[/backups]")
      engine.restore(image: "img:1", volume: "v", directory: "/tmp/b", file: "collector-backup-1.tar.gz")
      engine.copy_database(volume: "v", image: "img:1", into: "/tmp/out")
      engine.list_directory("img:1", "/tmp/b")
      engine.own("img:1", "/tmp/b")
      engine.remove_directory("img:1", "/tmp/s")
    end.not_to raise_error
    expect(calls).to all(start_with("docker"))
  end

  it "refuses a database task in any category (AC-3.4)", :aggregate_failures do
    %w[db:schema:load db:reset db:drop db:setup].each do |task|
      expect { refused(:runner, [ "exec", "-i", "c", "bin/rails", task ]) }.to raise_error(described_class::Failure, /database task/)
    end
  end

  it "refuses a task, a file command and a category that are not on the list", :aggregate_failures do
    expect { refused(:tasks, [ "exec", "c", "bin/rails", "db:migrate" ]) }.to raise_error(described_class::Failure, /not on the proof's list/)
    expect { refused(:files, [ "run", "--rm", "img", "rm", "-rf", "/etc" ], check: %w[rm -rf /etc]) }.to raise_error(described_class::Failure, /not on the proof's list/)
    expect { refused(:shell, [ "run", "sh" ]) }.to raise_error(described_class::Failure, /unknown command category/)
  end

  it "starts a container the way an operator does: the volume, the secret, the port, the flags and the entrypoint's boot", :aggregate_failures do
    engine.start(name: "c", volume: "v", secret: "s3", image: "img:1")
    expect(calls.last).to eq(%w[docker run -d --name c --platform linux/arm64 -p 127.0.0.1::8080 -v v:/rails/storage
      -e SECRET_KEY_BASE=s3 -e HTTP_PORT=8080 -e SOLID_QUEUE_IN_PUMA=true img:1])
  end

  it "restores with the dummy secret from a read-only directory, as the README documents (AC-6.1)" do
    engine.restore(image: "img:1", volume: "v", directory: "/tmp/b", file: "collector-backup-1.tar.gz")
    expect(calls.last).to eq(%w[docker run --rm -u 1000 --platform linux/arm64 -v v:/rails/storage -v /tmp/b:/backups:ro
      -e SECRET_KEY_BASE_DUMMY=1 img:1 bin/rails backup:restore[/backups/collector-backup-1.tar.gz]])
  end

  it "copies out the main database file and any -wal and -shm, not the other databases (AC-2.4)", :aggregate_failures do
    engine.copy_database(volume: "v", image: "img:1", into: "/tmp/out")
    copy = calls.find { it.include?("cp") }
    expect(copy.last(3)).to eq(%w[/rails/storage/production.sqlite3 /rails/storage/production.sqlite3-wal /out/])
    expect(copy).not_to include("/rails/storage/production_cache.sqlite3")
  end

  it "has a fake that answers every builder, so the harness specs cover what the harness calls" do
    fake = FakeEngine.new
    expect(described_class.public_instance_methods(false)).to all(satisfy { |name| fake.respond_to?(name) })
  end

  it "keeps every forbidden task name in one constant and out of every other line of the harness (AC-3.4, AC-8.3)", :aggregate_failures do
    files = Dir[Rails.root.join("script/upgrade/**/*.rb").to_s] + [ Rails.root.join("bin/upgrade-smoke").to_s ].select { File.exist?(it) }
    pattern = /db:(schema:load|reset|drop|setup)/
    hits = files.flat_map { |file| File.readlines(file).grep(pattern).map { |line| [ File.basename(file), line.strip ] } }
    expect(hits.map(&:first).uniq).to eq([ "engine.rb" ])
    expect(hits.map(&:last)).to all(start_with("FORBIDDEN ="))
  end

  it "starts a process only in engine.rb (the container CLI) and release.rb (read-only git) (AC-8.3)" do
    spawning = /Open3|\bsystem\(|\bspawn\(|%x[\[{(]|IO\.popen|Kernel\.exec|Process\.(spawn|exec)/
    files = Dir[Rails.root.join("script/upgrade/**/*.rb").to_s] + [ Rails.root.join("bin/upgrade-smoke").to_s ].select { File.exist?(it) }
    offenders = files.reject { File.basename(it).then { |name| %w[engine.rb release.rb].include?(name) } }.select { File.read(it).match?(spawning) }
    expect(offenders).to be_empty
  end
end
