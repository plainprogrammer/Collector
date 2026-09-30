module ApplicationHelper
  # One id per error message ("email_address-error", "email_address-error-2", …), so a
  # control can reference every message under it without repeating an id on the page.
  def field_error_ids(id, messages)
    messages.each_index.map { |index| index.zero? ? id : "#{id}-#{index + 1}" }
  end

  # The aria-describedby value for a control: its error message ids, or nil when it's valid.
  def field_error_describedby(id, messages)
    field_error_ids(id, messages).join(" ").presence
  end
end
