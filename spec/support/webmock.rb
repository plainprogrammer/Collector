# frozen_string_literal: true

require "webmock/rspec"

# Disable external HTTP requests by default in tests
WebMock.disable_net_connect!(allow_localhost: true)
