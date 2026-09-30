module LotsHelper
  def lot_error_messages(form, field)
    form.errors.where(field).map { |error| error.message.match?(/\A[A-Z]/) ? error.message : error.full_message }
  end
end
