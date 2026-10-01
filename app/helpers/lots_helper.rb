module LotsHelper
  def lot_error_messages(form, field)
    form.errors.where(field).map { |error| error.message.match?(/\A[A-Z]/) ? error.message : error.full_message }
  end

  # A lot's finish (spec 004 AC-8.5): a special finish as the one badge, any other as muted text, "—" if unspecified.
  def lot_finish(lot)
    return "—" unless lot.finish

    label = lot.vocabulary.finish_label(lot.finish)
    lot.vocabulary.special_finishes.include?(lot.finish) ? render("catalog/entries/finish_badge", label:) : tag.span(label, class: "is-muted")
  end

  def lot_condition(lot) = lot.condition ? lot.vocabulary.conditions.fetch(lot.condition).last : "—"

  def lot_price(lot) = lot.price_paid ? number_to_currency(lot.price_paid, unit: Rails.configuration.x.currency.symbol) : "—"

  # Names a lot for assistive technology: "Lightning Bolt M10 · 146 Foil NM" (spec 006 AC-2.5).
  def lot_label(lot)
    vocabulary = lot.vocabulary
    [ lot.entry.name, set_number(lot.entry), (vocabulary.finish_label(lot.finish) if lot.finish),
      (vocabulary.conditions.fetch(lot.condition).last if lot.condition) ].compact.join(" ")
  end

  # The phone line under a row's name (spec 006 AC-2.8): set · number, finish, condition, language.
  def lot_summary(lot)
    [ set_number(lot.entry), (lot.vocabulary.finish_label(lot.finish) if lot.finish),
      (lot.vocabulary.conditions.fetch(lot.condition).last if lot.condition), lot.entry.language.upcase ].compact.join(" · ")
  end
end
