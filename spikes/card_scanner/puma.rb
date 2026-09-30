# Puma config for the spike server only; bound to all interfaces so the iPhone can reach it on the LAN.
port Integer(ENV.fetch("SPIKE_PORT", 4100)), "0.0.0.0"
rackup File.expand_path("config.ru", __dir__)
threads 1, 4
