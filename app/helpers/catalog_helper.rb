module CatalogHelper
  # Returns the URL only when it is https on a host a registered catalog source vouches for.
  def catalog_url(url)
    uri = URI.parse(url.to_s)
    url if uri.is_a?(URI::HTTPS) && Catalog.allowed_hosts.include?(uri.host)
  rescue URI::InvalidURIError
    nil
  end

  # One [image_url, name] pair per distinct face image, in face order; faces sharing an image (or
  # sharing no image) are named together, e.g. "Bonecrusher Giant // Stomp".
  def face_images(entry)
    faces = entry.extension&.faces.presence || [ { "image_uris" => { "normal" => entry.image_url }, "name" => entry.name } ]
    faces.group_by { |face| face.dig("image_uris", "large") || face.dig("image_uris", "normal") }
      .map { |image, shared| [ image, shared.map { |face| face["name"] }.join(" // ") ] }
  end

  def set_number(entry) ="#{entry.set.code.upcase} · #{entry.number}"

  def quick_add_button(entry, return_to:, label: "Add")
    button_to catalog_entry_quick_add_path(entry), params: { return_to: }, class: "c-btn c-btn--ghost c-btn--sm",
      form: { class: "c-tile__add", data: { turbo_frame: "_top" } },
      "aria-label": "Add 1 × #{entry.name} (#{set_number(entry)})" do
      safe_join([ render("icons/plus"), label ])
    end
  end

  # Renders the collectible-specific partial for an entry, e.g. mtg/printings/_details.
  def render_catalog_extension(entry, part)
    return if entry.extension.nil?

    render partial: "#{entry.extension.model_name.collection}/#{part}", locals: { extension: entry.extension }
  end
end
