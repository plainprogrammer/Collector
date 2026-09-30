module MTGHelper
  def mana_cost_tag(cost, large: false)
    mana = MTG::ManaCost.new(cost)
    return if mana.pips.empty?

    tag.span(class: class_names("c-cost", "c-cost--lg": large), role: "img", "aria-label": mana.label) do
      safe_join(mana.pips.map { |pip| tag.span(pip.text, class: pip.css, "aria-hidden": "true") })
    end
  end
end
