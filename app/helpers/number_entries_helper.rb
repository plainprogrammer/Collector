module NumberEntriesHelper
  # "Psychic Frog (MH3 · 47, <finish label>)": a line's card, set and number, and finish (spec 026).
  def number_entry_copy(line)
    "#{line.entry.name} (#{[ set_number(line.entry), number_entry_finish_label(line) ].compact.join(", ")})"
  end

  # A line's finish as the copies table shows one (spec 004 AC-8.5): a special finish as the one badge, any other as
  # muted text, "—" when it has none.
  def number_entry_finish(line)
    label = number_entry_finish_label(line)
    return "—" unless label

    special = Catalog.collecting_for(line.entry.collectible_type).special_finishes.include?(line.finish)
    special ? render("catalog/entries/finish_badge", label:) : tag.span(label, class: "is-muted")
  end

  def number_entry_finish_label(line) = line.finish && Catalog.collecting_for(line.entry.collectible_type).finish_label(line.finish)
end
