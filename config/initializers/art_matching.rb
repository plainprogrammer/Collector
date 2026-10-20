# Spec 011 AC-1.2: COLLECTOR_MTG_ART_MATCHING is parsed once, into the app's configuration, which every caller reads.
# after_initialize, because the parser lives in app/ (MTG::Art) and can't be referenced while config loads. Tests never
# read the environment (a developer's exported variable mustn't turn art on in the suite); examples set the configuration.
Rails.application.config.after_initialize do
  Rails.configuration.x.mtg_art_matching = !Rails.env.test? && MTG::Art.enabled_in?(ENV)
end
