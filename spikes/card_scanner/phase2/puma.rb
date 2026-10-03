port Integer(ENV.fetch("SPIKE_PORT", 4200)), "127.0.0.1"
rackup File.expand_path("config.ru", __dir__)
threads 1, 4
