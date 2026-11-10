# Keyboard navigation for system specs (spec 029 AC-5.5; spec 059).
module KeyboardHelpers
  # Presses Tab, moving the browser's focus, until a focused control (never the page's body, whose text includes
  # everything) has text that includes the given text, at most 40 times; false if none does. Focus stays on the control
  # it found, so the caller can press a key on it.
  #
  # @param text [String] text the focused control's content must include
  # @return [Boolean] whether a control with that text was focused
  def tab_to_text(text)
    40.times do
      return true if page.evaluate_script("document.activeElement !== document.body && document.activeElement.textContent.includes(arguments[0])", text)

      page.driver.browser.action.send_keys(:tab).perform
    end
    false
  end
end

RSpec.configure do |config|
  config.include KeyboardHelpers, type: :system
end
