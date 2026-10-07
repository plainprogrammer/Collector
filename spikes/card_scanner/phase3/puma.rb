# The art spike's server (spec 010): HTTPS on the LAN for the phone (spec 007's certificate), plain HTTP on loopback for the
# desktop replay. Start: CARD_SCANNER_WORK_DIR=… bundle exec puma -C spikes/card_scanner/phase3/puma.rb
cert = File.expand_path(ENV.fetch("CERT_DIR", "~/.local/share/collector-dev-https"))
bind "ssl://0.0.0.0:#{ENV.fetch("SPIKE_PORT", 4300)}?key=#{cert}/dev.key&cert=#{cert}/dev.crt"
bind "tcp://127.0.0.1:#{ENV.fetch("SPIKE_LOCAL_PORT", 4301)}"
rackup File.expand_path("config.ru", __dir__)
threads 1, 4
