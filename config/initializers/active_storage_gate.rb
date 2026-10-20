Rails.application.config.to_prepare do
  ActiveStorage::BaseController.include ActiveStorageGate
end
