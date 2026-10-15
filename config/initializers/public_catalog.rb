# Spec 023 AC-1.2: COLLECTOR_PUBLIC_CATALOG is parsed once, into the app's configuration, which Catalog.public? reads.
# after_initialize, because the parser lives in app/ (Catalog) and can't be referenced while config loads. Tests never
# read the environment (a developer's exported variable mustn't open the catalog in the suite); examples set the
# configuration (the :public_catalog tag).
Rails.application.config.after_initialize do
  Rails.configuration.x.public_catalog = !Rails.env.test? && Catalog.public_in?(ENV)
end
