# Spec 025: how the import preview writes a lot or a row, and its copy counts.
module ImportPreviewsHelper
  PRICE = /\A(0|[1-9][0-9]*)\.[0-9]{2}\z/

  # Set code and number, language, then whatever finish, condition and price it has: "DMR · 27 · EN · Foil · $12.50".
  # A price the file doesn't write in the format's form is shown as the file gives it.
  def import_lot_line(set_code:, collector_number:, language:, finish:, condition:, price_paid:)
    price = price_paid&.match?(PRICE) ? number_to_currency(price_paid, unit: Rails.configuration.x.currency.symbol) : price_paid
    [ [ set_code&.upcase, collector_number ].compact.join(" · ").presence, language&.upcase, finish&.humanize, condition&.humanize, price ]
      .compact.join(" · ")
  end

  def import_copies(count) = pluralize(number_with_delimiter(count), "copy")

  # "6 copies become 9", "1 copy becomes 2".
  def import_change(tally) = "#{import_copies(tally.copies)} #{tally.copies == 1 ? "becomes" : "become"} #{number_with_delimiter(tally.copies_after)}"
end
