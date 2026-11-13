require "rails_helper"
require "rake"

# The container's start check at process level (spec 086): the task has no :environment prerequisite and nothing on the
# application's boot path reaches it (decisions 1, 3 and 5; AC-2.6).
RSpec.describe "the start check", :backup, type: :task do
  # Every file a boot of the application reads: initializers, the application and environment configuration, and app/.
  def boot_files
    Rails.root.glob("{config/initializers/**/*.rb,config/application.rb,config/environments/*.rb,app/**/*.rb}")
  end

  # The code lines of a file, without comments and without config/application.rb's autoload_lib(ignore:) line, which
  # names the file so that Zeitwerk leaves it alone and is no run of it.
  def code_lines(file)
    file.each_line.reject { it.include?("autoload_lib(ignore:") }.map { it.sub(/(\A|\s)#.*/, "") }
  end

  it "gives start:check no dependency on :environment, so it initializes nothing (AC-2.6)" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("start:check")

    expect(Rake::Task["start:check"].all_prerequisite_tasks.map(&:name)).not_to include("environment")
  end

  it "is not named by any initializer, configuration file or app file, so no boot runs it (AC-2.6)" do
    named = boot_files.select { |file| code_lines(file).any? { it.match?(/StartCheck|start_check/) } }

    expect(named).to be_empty, "these files name the start check: #{named.join(", ")}"
  end
end
