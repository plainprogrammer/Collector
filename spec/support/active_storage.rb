# The specs of spec 028 create blobs on the test Disk service (tmp/storage); empty it after the suite, keeping the
# directory and its .keep file (the repository tracks it).
RSpec.configure do |config|
  config.after(:suite) do
    root = Pathname(ActiveStorage::Blob.service.root)
    root.children.reject { |child| child.basename.to_s == ".keep" }.each { |child| FileUtils.rm_rf(child) } if root.exist?
  end
end
