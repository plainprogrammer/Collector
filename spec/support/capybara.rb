require "capybara/rspec"
require "capybara/cuprite"

Capybara.register_driver(:cuprite_custom) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size: [ 1400, 1000 ],
    headless: true,
    process_timeout: 10,
    timeout: 10,
    browser_options: {
      "no-sandbox": true,
      "disable-gpu": true,
      "disable-dev-shm-usage": true
    }
  )
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :cuprite_custom
  end

  config.after(:each, type: :system) do |example|
    if example.exception
      timestamp = Time.current.strftime("%Y%m%d%H%M%S")
      filename = "tmp/screenshots/#{example.full_description.parameterize}-#{timestamp}.png"
      page.save_screenshot(filename)
      puts "\n📸 Screenshot saved: #{filename}"
    end
  end
end
