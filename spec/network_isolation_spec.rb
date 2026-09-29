require "rails_helper"

RSpec.describe "Network isolation" do
  it "blocks real outbound HTTP requests" do
    expect { Net::HTTP.get(URI("https://example.com/")) }
      .to raise_error(VCR::Errors::UnhandledHTTPRequestError, %r{example\.com})
  end
end
