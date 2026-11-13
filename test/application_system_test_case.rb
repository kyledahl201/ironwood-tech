require "test_helper"

# Browser tests run headless Chrome. CHROME_BIN points at a Chrome or Chromium
# binary when it isn't on the usual path (Selenium Manager finds a matching
# driver).
# CHROMEDRIVER_PATH uses that driver instead of asking Selenium Manager (which needs the network).
Selenium::WebDriver::Chrome::Service.driver_path = ENV["CHROMEDRIVER_PATH"] if ENV["CHROMEDRIVER_PATH"].present?

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ] do |options|
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
  end
end
