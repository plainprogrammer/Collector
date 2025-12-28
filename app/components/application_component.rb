# frozen_string_literal: true

class ApplicationComponent < ViewComponent::Base
  # Base class for all components in the application.
  # Provides shared helpers and conventions for ViewComponents.

  # Parses mana cost symbols (e.g., "{2}{W}{W}") and renders appropriate markup.
  # This is a placeholder implementation - will be enhanced when implementing MTG card display.
  #
  # @param cost_string [String] The mana cost string with symbols like {W}, {U}, {2}
  # @return [String] HTML-safe string with mana symbol markup
  def mana_symbols(cost_string)
    return "" if cost_string.blank?

    # Placeholder: will be implemented with actual mana symbol rendering
    # when card detail components are built
    tag.span(cost_string, class: "mana-cost")
  end

  # Returns appropriate Tailwind CSS classes for a condition badge.
  #
  # @param condition [String] The condition code (NM, LP, MP, HP, DMG)
  # @return [String] CSS classes for styling the condition badge
  def condition_class(condition)
    base_classes = "inline-flex items-center rounded-md px-2 py-1 text-xs font-medium"

    condition_colors = {
      "NM" => "bg-green-50 text-green-700 ring-1 ring-inset ring-green-600/20",
      "LP" => "bg-blue-50 text-blue-700 ring-1 ring-inset ring-blue-600/20",
      "MP" => "bg-yellow-50 text-yellow-800 ring-1 ring-inset ring-yellow-600/20",
      "HP" => "bg-orange-50 text-orange-700 ring-1 ring-inset ring-orange-600/20",
      "DMG" => "bg-red-50 text-red-700 ring-1 ring-inset ring-red-600/20"
    }

    color_classes = condition_colors[condition] || "bg-gray-50 text-gray-600 ring-1 ring-inset ring-gray-500/10"
    "#{base_classes} #{color_classes}"
  end

  # Returns appropriate Tailwind CSS classes for a finish badge.
  #
  # @param finish [String] The finish type (nonfoil, foil, etched)
  # @return [String] CSS classes for styling the finish badge
  def finish_class(finish)
    base_classes = "inline-flex items-center rounded-md px-2 py-1 text-xs font-medium"

    finish_colors = {
      "nonfoil" => "bg-gray-50 text-gray-600 ring-1 ring-inset ring-gray-500/10",
      "foil" => "bg-purple-50 text-purple-700 ring-1 ring-inset ring-purple-700/10",
      "etched" => "bg-indigo-50 text-indigo-700 ring-1 ring-inset ring-indigo-700/10"
    }

    color_classes = finish_colors[finish] || "bg-gray-50 text-gray-600 ring-1 ring-inset ring-gray-500/10"
    "#{base_classes} #{color_classes}"
  end
end
