# Card images in system specs (spec 019, Testability). The suite's browser must never ask a catalog source for a
# picture, so a test entry's image address is https on a port Firefox refuses to open: the page renders the <img>
# and nothing leaves the machine. An example then hands each rendered <img> a picture as a data: address and reads
# back where the browser's own fitting rules put it.
module CardImages
  HOST = "127.0.0.1".freeze
  EDGE = 0.01 # CSS pixels: rounding in the browser's layout units

  # One <img>'s fit, in CSS pixels. `slot` and `box` are content boxes ([width, height]); `painted` is the picture's
  # [left, top, width, height] inside the box, from the computed object-fit and object-position (CSS Images 3,
  # section 5.5), which is how the browser places it.
  Fit = Data.define(:fit, :slot, :box, :natural, :painted, :ground, :sunken) do
    # What is wrong with this fit, in words; empty when the image is shown whole, in its own proportions, centred and
    # as large as its 63:88 slot allows, on surface-sunken.
    def faults
      left, top, width, height = painted
      [].tap do |faults|
        faults << "cropped: #{describe}" if left < -EDGE || top < -EDGE || left + width > box[0] + EDGE || top + height > box[1] + EDGE
        faults << "stretched: #{describe}" unless ((width / natural[0]) / (height / natural[1]) - 1).abs <= 0.001
        faults << "off centre: #{describe}" unless (box[0] - width - 2 * left).abs <= EDGE && (box[1] - height - 2 * top).abs <= EDGE
        faults << "smaller than its box: #{describe}" unless (box[0] - width).abs <= EDGE || (box[1] - height).abs <= EDGE
        faults << "slot is #{slot.join(' × ')}, not 63:88" unless (slot[1] - slot[0] * 88 / 63.0).abs <= 0.1
        faults << "ground is #{ground}, not surface-sunken (#{sunken})" unless ground == sunken
      end
    end

    def describe
      "a #{natural.join(' × ')} picture painted #{painted.last(2).map { it.round(2) }.join(' × ')} " \
        "at #{painted.first(2).map { it.round(2) }.join(', ')} in a #{box.join(' × ')} box (object-fit: #{fit})"
    end
  end

  # arguments: a selector for the images, the pictures to give them in turn. Each image's data-card-picture says how it
  # got on: pending until its picture loads (loaded) or fails (failed). The script returns at once, and the example
  # waits for the images with Capybara: the asynchronous script call that did both failed sometimes with an empty
  # message (issue #127; in the one reproduction the page had finished and the driver's reply was lost), and a
  # result of the form { error: … } is read by geckodriver as its own error.
  PICTURES = <<~JS.freeze
    const [ selector, pictures ] = arguments
    document.querySelectorAll(selector).forEach((image, index) => {
      image.dataset.cardPicture = "pending"
      image.addEventListener("load", () => { image.dataset.cardPicture = "loaded" }, { once: true })
      image.addEventListener("error", () => { image.dataset.cardPicture = "failed" }, { once: true })
      image.loading = "eager"
      image.src = pictures[index % pictures.length]
    })
  JS

  # arguments: a selector for the images. Where the browser puts each one's picture.
  FITS = <<~JS.freeze
    const [ selector ] = arguments
    const px = (value) => parseFloat(value) || 0
    const round = (value) => Math.round(value * 1000) / 1000 // the browser reports sizes with float noise far below this
    const inner = (element) => {
      const style = getComputedStyle(element), rect = element.getBoundingClientRect()
      return [ rect.width - px(style.borderLeftWidth) - px(style.borderRightWidth) - px(style.paddingLeft) - px(style.paddingRight),
        rect.height - px(style.borderTopWidth) - px(style.borderBottomWidth) - px(style.paddingTop) - px(style.paddingBottom) ].map(round)
    }
    const probe = document.body.appendChild(document.createElement("i"))
    probe.style.backgroundColor = "var(--surface-sunken)"
    const sunken = getComputedStyle(probe).backgroundColor
    probe.remove()
    const groundOf = (image, slot) => {
      for (let element = image; element; element = element.parentElement) {
        const colour = getComputedStyle(element).backgroundColor
        if (colour !== "rgba(0, 0, 0, 0)" && colour !== "transparent") return colour
        if (element === slot) return null
      }
    }
    const fitOf = (image) => {
      const slot = image.closest(".c-tile__media, .c-item__image") || image
      const style = getComputedStyle(image), [ boxWidth, boxHeight ] = inner(image)
      const [ naturalWidth, naturalHeight ] = [ image.naturalWidth, image.naturalHeight ]
      const contain = Math.min(boxWidth / naturalWidth, boxHeight / naturalHeight)
      const cover = Math.max(boxWidth / naturalWidth, boxHeight / naturalHeight)
      const [ scaleX, scaleY ] = { fill: [ boxWidth / naturalWidth, boxHeight / naturalHeight ], contain: [ contain, contain ],
        cover: [ cover, cover ], none: [ 1, 1 ], "scale-down": [ Math.min(1, contain), Math.min(1, contain) ] }[style.objectFit]
      const [ width, height ] = [ naturalWidth * scaleX, naturalHeight * scaleY ]
      const [ shareX, shareY ] = style.objectPosition.split(" ").map((share) => parseFloat(share) / 100)
      return { fit: style.objectFit, slot: inner(slot), box: [ boxWidth, boxHeight ], natural: [ naturalWidth, naturalHeight ],
        painted: [ (boxWidth - width) * shareX, (boxHeight - height) * shareY, width, height ], ground: groundOf(image, slot), sunken }
    }
    return [ ...document.querySelectorAll(selector) ].map(fitOf)
  JS

  # arguments: a selector. Each matching element's top edge, border box (outer), content box and row height (null outside
  # a table).
  BOXES = <<~JS.freeze
    const px = (value) => parseFloat(value) || 0
    const round = (value) => Math.round(value * 1000) / 1000 // the browser reports sizes with float noise far below this
    return [ ...document.querySelectorAll(arguments[0]) ].map((element) => {
      const style = getComputedStyle(element), rect = element.getBoundingClientRect(), row = element.closest("tr")
      return { tag: element.tagName.toLowerCase(), top: round(rect.top), outer: [ rect.width, rect.height ].map(round),
        box: [ rect.width - px(style.borderLeftWidth) - px(style.borderRightWidth) - px(style.paddingLeft) - px(style.paddingRight),
          rect.height - px(style.borderTopWidth) - px(style.borderBottomWidth) - px(style.paddingTop) - px(style.paddingBottom) ].map(round),
        row: row && round(row.getBoundingClientRect().height) }
    })
  JS

  # An image address catalog_url accepts (with `:card_images`) and nothing answers.
  def card_image_address(name = "card") = "https://#{HOST}:9/#{name}.png"

  # A plain picture of the given size, as a data: address.
  def card_picture(width, height)
    "data:image/png;base64,#{Base64.strict_encode64(png_bytes(width, height) { [ 196, 30, 90 ] })}"
  end

  # The fit of every image matching the selector, after giving them the pictures in turn (they repeat).
  def card_image_fits(selector, pictures: [])
    result = begin
      give_card_pictures(selector, pictures) if pictures.any?
      page.evaluate_script("(function () { #{FITS} }).apply(null, arguments)", selector)
    rescue Selenium::WebDriver::Error::WebDriverError => error
      raise error, "#{error.class}: #{error.message.presence || '(no message)'}; #{card_image_state(selector)}", error.backtrace
    end

    result.map { |fit| Fit.new(**fit.to_h { |key, value| [ key.to_sym, value.is_a?(Array) ? value.map(&:to_f) : value ] }) }
  end

  # Hands each image its picture and waits until every one has loaded; a picture that fails to load is an error.
  def give_card_pictures(selector, pictures)
    page.execute_script(PICTURES, selector, pictures)
    page.assert_no_selector(:css, "#{selector}[data-card-picture='pending']", visible: :all)
    raise "a test picture did not load" if page.has_css?("#{selector}[data-card-picture='failed']", visible: :all, wait: 0)
  end

  # Where the page was when the browser dropped a measurement (issue #127: geckodriver reports a lost context with an
  # empty message). Read in a second call, which may fail as well, and says so.
  def card_image_state(selector)
    state = page.evaluate_script(<<~JS, selector)
      (() => ({ url: location.href, ready: document.readyState, framed: window !== window.top,
        images: [ ...document.querySelectorAll(arguments[0]) ].map((image) => image.complete + "/" + image.naturalWidth) }))()
    JS
    "page state afterwards: #{state.to_json}"
  rescue StandardError => error
    "page state afterwards unreadable (#{error.class}: #{error.message.to_s.lines.first&.strip})"
  end

  def card_slot_boxes(selector) = page.evaluate_script("(function () { #{BOXES} })(#{selector.to_json})")

  def use_dark_theme = page.execute_script("document.documentElement.dataset.theme = 'dark'")
end

RSpec.configure do |config|
  config.include CardImages, type: :system
  # catalog_url passes https addresses on a source's hosts only; these examples add the one nothing answers.
  config.before(:each, :card_images) do
    allow(Catalog).to receive(:allowed_hosts).and_return(Catalog.allowed_hosts + [ CardImages::HOST ])
  end
end
