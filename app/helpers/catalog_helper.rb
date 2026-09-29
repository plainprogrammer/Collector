module CatalogHelper
  # Returns the URL only when it is https on a host a registered catalog source vouches for.
  def catalog_url(url)
    uri = URI.parse(url.to_s)
    url if uri.is_a?(URI::HTTPS) && Catalog.allowed_hosts.include?(uri.host)
  rescue URI::InvalidURIError
    nil
  end

  # Renders the collectible-specific partial for an entry, e.g. mtg/printings/_summary.
  def render_catalog_extension(entry, part)
    return if entry.extension.nil?

    render partial: "#{entry.extension.model_name.collection}/#{part}", locals: { extension: entry.extension }
  end
end
