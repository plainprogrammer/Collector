# Drives the scanner page in system specs (spec 007; ADR 0002): a synthetic 63:88 card, drawn so its name and
# collector line sit inside the page's strips, stands in for the camera or a picked photo.
module ScannerHelpers
  CARD_JS = <<~JS.freeze
    // WebDriver runs this in a sandbox without the page's import map, so load the page's own geometry module
    // through a module script carrying the page's nonce.
    window.__geometry ||= new Promise((resolve) => {
      addEventListener("geometry-ready", () => resolve(window.__scannerGeometry), { once: true })
      const script = Object.assign(document.createElement("script"), { type: "module", nonce: document.querySelector("script[type=importmap]")?.nonce || "" })
      script.textContent = `import * as geometry from "scanner/geometry"; window.__scannerGeometry = geometry; dispatchEvent(new Event("geometry-ready"))`
      document.head.append(script)
    })
    // A live card is drawn where the page's guide falls in the frame (spec 082 AC-3.1): the stage's live guide mapped into the
    // 3:4 frame the way the camera controller maps it; a photo's card where the shipped guide is (the photo path's framing).
    // flat paints the background white as well, so the photo has no card edge for the detector to find (spec 088 AC-1.3).
    window.__syntheticCard = async (name, lines, live = false, flat = false) => {
      const { guideRect, guideInFrame, liveGuideRect } = await window.__geometry
      const canvas = Object.assign(document.createElement("canvas"), { width: 900, height: 1200 })
      const context = canvas.getContext("2d")
      const cardBox = () => {
        const stage = document.querySelector(".c-scan__stage")?.getBoundingClientRect()
        if (!live || !stage) return guideRect(canvas.width, canvas.height)
        const framing = document.querySelector(".c-scan")?.dataset.cameraFramingValue || "full"
        return guideInFrame(canvas.width, canvas.height, stage.width, stage.height, liveGuideRect(stage.width, stage.height, framing))
      }
      // Text is sized and placed from the card, as on a real card, so strip tuning doesn't change the test text.
      const draw = () => {
        const card = cardBox()
        context.fillStyle = flat ? "white" : "gray"; context.fillRect(0, 0, canvas.width, canvas.height)
        context.fillStyle = "white"; context.fillRect(card.x, card.y, card.width, card.height)
        context.fillStyle = "black"; context.textBaseline = "middle"
        context.font = `${Math.round(card.height * 0.045)}px sans-serif`
        context.fillText(name, card.x + card.width * 0.08, card.y + card.height * 0.10)
        context.font = `${Math.round(card.height * 0.022)}px sans-serif`
        lines.forEach((line, index) => context.fillText(line, card.x + card.width * 0.06, card.y + card.height * (0.935 + 0.03 * index)))
      }
      draw()
      return { canvas, draw }
    }
    if (!window.__sent) { // records the field names of every form the page posts; files show as "<name>:file"
      window.__sent = []
      const send = window.fetch
      window.fetch = (url, options = {}) => {
        if (options.body instanceof FormData) window.__sent.push([ ...options.body.entries() ].map(([ key, value ]) => typeof value === "string" ? key : `${key}:file`))
        return send(url, options)
      }
    }
  JS

  # Loads the page's own scanner modules into the WebDriver sandbox, as CARD_JS loads geometry (spec 009 Story 7).
  MODULES_JS = <<~JS.freeze
    window.__modules ||= new Promise((resolve) => {
      addEventListener("modules-ready", () => resolve(window.__scannerModules), { once: true })
      const script = Object.assign(document.createElement("script"), { type: "module", nonce: document.querySelector("script[type=importmap]")?.nonce || "" })
      script.textContent = `import * as geometry from "scanner/geometry"; import * as detector from "scanner/detector"; window.__scannerModules = { geometry, detector }; dispatchEvent(new Event("modules-ready"))`
      document.head.append(script)
    })
  JS

  # Adds seeded sensor noise of up to noise levels to a picture, the same on every run.
  NOISE_JS = <<~JS.freeze
    window.__addNoise = (context, width, height, noise) => {
      if (noise <= 0) return
      const image = context.getImageData(0, 0, width, height)
      let seed = 1
      for (let i = 0; i < image.data.length; i += 4) {
        seed = (seed * 16807) % 2147483647
        for (let channel = 0; channel < 3; channel++) image.data[i + channel] += (seed % (2 * noise + 1)) - noise
      }
      context.putImageData(image, 0, 0)
    }
  JS

  # The picker input a photo is picked through unless a spec names another.
  PICKER = "[data-card-reader-target=picker]".freeze

  # Detection runs on a full-size picture, so the detector specs give their scripts longer than Capybara's default wait.
  DETECTION_SCRIPT_WAIT = 30

  # What the shipped detector finds in a grey photo with a white card-shaped rectangle, optionally tilted. noise adds
  # seeded sensor noise of up to that many levels; with none, over half the edge strengths are 0, so the detector's edge
  # threshold is 0 (the spike then counted every flat pixel as a horizontal edge; the shipped detector skips them).
  def detect_synthetic(card:, width: 1200, height: 1600, tilt_degrees: 0, noise: 0)
    using_wait_time(DETECTION_SCRIPT_WAIT) { page.evaluate_async_script(<<~JS, width, height, card, tilt_degrees, noise) }
      const [ width, height, card, tilt, noise, done ] = arguments
      #{MODULES_JS}
      #{NOISE_JS}
      window.__modules.then(({ detector }) => {
        const canvas = Object.assign(document.createElement("canvas"), { width, height })
        const context = canvas.getContext("2d")
        context.fillStyle = "#555"; context.fillRect(0, 0, width, height)
        if (card) {
          context.translate(card.x + card.width / 2, card.y + card.height / 2); context.rotate(tilt * Math.PI / 180)
          context.fillStyle = "white"; context.fillRect(-card.width / 2, -card.height / 2, card.width, card.height)
        }
        window.__addNoise(context, width, height, noise)
        const found = detector.findCard(canvas)
        done({ found: found.found, corners: found.corners || null, picture: found.picture ? [ found.picture.width, found.picture.height ] : null })
      })
    JS
  end

  # What the shipped detector finds in pick_synthetic_photo's picture (a flat card in the guide), with the guide's box.
  def detect_guide_card
    using_wait_time(DETECTION_SCRIPT_WAIT) { page.evaluate_async_script(<<~JS) }
      const done = arguments[0]
      #{CARD_JS}
      #{MODULES_JS}
      Promise.all([ window.__syntheticCard("Lightning Bolt", [ "R 0123", "MOM • EN" ]), window.__modules ]).then(([ { canvas }, { geometry, detector } ]) => {
        const card = geometry.guideRect(canvas.width, canvas.height)
        done({ corners: detector.findCard(canvas).corners || null, card: { x: card.x, y: card.y, width: card.width, height: card.height } })
      })
    JS
  end

  # Runs the page's refineStrip on fresh 40×10 strips (20 grey with a 200 block): the name strip with invertBelow 128, the
  # collector strip binarized at twice the size (spec 009 AC-6.2, AC-6.3).
  def refine_synthetic_strips
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      #{MODULES_JS}
      window.__modules.then(({ geometry }) => {
        const strip = () => {
          const canvas = Object.assign(document.createElement("canvas"), { width: 40, height: 10 })
          const context = canvas.getContext("2d")
          context.fillStyle = "rgb(20,20,20)"; context.fillRect(0, 0, 40, 10)
          context.fillStyle = "rgb(200,200,200)"; context.fillRect(5, 3, 10, 4)
          return canvas
        }
        const inverted = geometry.refineStrip("name", strip(), { invertBelow: 128 })
        const flat = geometry.refineStrip("collector", strip(), { binarize: true, scale: 2 })
        const pixel = (canvas, x, y) => canvas.getContext("2d").getImageData(x, y, 1, 1).data[0]
        done({ background: pixel(inverted, 0, 0), text: pixel(inverted, 6, 4), size: [ flat.width, flat.height ], levels: [ pixel(flat, 0, 0), pixel(flat, 12, 8) ] })
      })
    JS
  end

  # Picks a photo of a synthetic card drawn anywhere in it (or none), so the detector rather than the guide has to find it.
  # noise is detect_synthetic's: a flat photo gives the detector no real edge strengths to threshold on.
  # input is the CSS selector of the picker to fire (spec 082 AC-2.2): the stage notice's by default, which comes first in the page.
  def pick_photo(card: { x: 40, y: 360, width: 859, height: 1200 }, width: 1200, height: 1600, name: "Lightning Bolt", lines: [ "R 0123", "MOM • EN" ], noise: 0, input: PICKER)
    using_wait_time(DETECTION_SCRIPT_WAIT) { page.evaluate_async_script(<<~JS, width, height, card, name, lines, noise, input) }
      const [ width, height, card, name, lines, noise, selector, done ] = arguments
      #{CARD_JS}
      #{NOISE_JS}
      const canvas = Object.assign(document.createElement("canvas"), { width, height })
      const context = canvas.getContext("2d")
      context.fillStyle = "#555"; context.fillRect(0, 0, width, height)
      if (card) {
        context.fillStyle = "white"; context.fillRect(card.x, card.y, card.width, card.height)
        context.fillStyle = "black"; context.textBaseline = "middle"
        context.font = `${Math.round(card.height * 0.045)}px sans-serif`
        context.fillText(name, card.x + card.width * 0.08, card.y + card.height * 0.10)
        context.font = `${Math.round(card.height * 0.022)}px sans-serif`
        lines.forEach((line, index) => context.fillText(line, card.x + card.width * 0.06, card.y + card.height * (0.935 + 0.03 * index)))
      }
      window.__addNoise(context, width, height, noise)
      canvas.toBlob((blob) => {
        const transfer = new DataTransfer()
        transfer.items.add(new File([ blob ], "card.png", { type: "image/png" }))
        const input = document.querySelector(selector)
        input.files = transfer.files
        input.dispatchEvent(new Event("change", { bubbles: true }))
        done(true)
      }, "image/png")
    JS
  end

  # Puts a synthetic card in front of the camera (ADR 0002): getUserMedia answers with a canvas stream whose card is drawn where
  # the page's live guide falls in the frame (spec 082 AC-3.1), then the camera restarts and the feed is waited for.
  #
  # @param name [String] the name drawn in the card's name bar
  # @param lines [Array<String>] the collector line's rows
  # @param torch [Boolean] whether the fake track reports a torch
  # @return [void]
  def show_synthetic_card(name: "Lightning Bolt", lines: [ "R 0123", "MOM • EN" ], torch: false)
    page.evaluate_async_script(<<~JS, name, lines, torch)
      const [ name, lines, torch, done ] = arguments
      #{CARD_JS}
      window.__syntheticCard(name, lines, true).then(({ canvas, draw }) => {
        window.__tracks = []; window.__cameraRequests = []; window.__torch = []
        navigator.mediaDevices.getUserMedia = async (constraints) => {
          window.__cameraRequests.push(constraints)
          const stream = canvas.captureStream(10)
          const track = stream.getVideoTracks()[0]
          setInterval(draw, 100)
          if (torch) {
            track.getCapabilities = () => ({ torch: true })
            track.applyConstraints = async (constraints) => { window.__torch.push(constraints.advanced[0].torch) }
          }
          window.__tracks.push(track)
          return stream
        }
        done(true)
      })
    JS
    restart_camera
    wait_for_scanner
    eventually("window.__tracks.length > 0 && document.querySelector('.c-scan__video').readyState >= 2")
  end

  # The engine has loaded and a live camera feed is showing (the shutter enables only then).
  def wait_for_scanner
    expect(page).to have_button("Capture", disabled: false, wait: 30)
  end

  # Picks a photo of a synthetic card at the shipped guide, through the picker input matches (see pick_photo). With flat: true
  # the photo's background is as white as the card, so the detector finds no edge and the reading is the guide placement's
  # (the result then carries the no-edge sentence, spec 088 AC-1.3).
  def pick_synthetic_photo(name: "Lightning Bolt", lines: [ "R 0123", "MOM • EN" ], input: PICKER, flat: false)
    page.evaluate_async_script(<<~JS, name, lines, input, flat)
      const [ name, lines, selector, flat, done ] = arguments
      #{CARD_JS}
      window.__syntheticCard(name, lines, false, flat).then(({ canvas }) => canvas.toBlob((blob) => {
        const transfer = new DataTransfer()
        transfer.items.add(new File([ blob ], "card.png", { type: "image/png" }))
        const input = document.querySelector(selector)
        input.files = transfer.files
        input.dispatchEvent(new Event("change", { bubbles: true }))
        done(true)
      }, "image/png"))
    JS
  end

  # Restarts the scanner's camera controller, so a getUserMedia substituted in the page is asked again.
  #
  # @return [void]
  def restart_camera
    page.execute_script(%(window.Stimulus.getControllerForElementAndIdentifier(document.querySelector(".c-scan"), "camera").restart()))
  end

  # Waits for a JavaScript expression to become truthy, the way Capybara's matchers wait for the DOM.
  def eventually(script, wait: 10)
    page.document.synchronize(wait) { page.evaluate_script(script) || raise(Capybara::ExpectationNotMet, script) }
  end

  def scanner_sent = page.evaluate_script("window.__sent")

  # Opens the scanner in a frame `width` × `height` from the collection page (the scanner's own policy frames nothing,
  # `frame-src 'none'`), and waits for the live feed. The page never scrolls, so the frame draws no scrollbar and its width is
  # the viewport's (spec 082 Verification).
  #
  # @param width [Integer] the frame's width in px
  # @param height [Integer] the frame's height in px
  # @param path [String] the page to open, the scanner or measurement mode
  # @return [Integer] the frame's viewport width
  def open_scanner_frame(width:, height:, path: scanner_path)
    visit collection_path
    open_in_narrow_frame(path, width:, height:, ready: ".c-scan__feed:not([hidden])").first
  end

  # The one-screen measures of the page the driver is in, read in one script (spec 082 AC-1.1, AC-1.2): whether the document
  # scrolls, after an attempt to scroll to its end, and the boxes of the bars, the stage and the main button.
  #
  # @return [Hash] "scrollable", "scrollY", "height" and "top", "stage", "bottom", "main" boxes (top, bottom)
  def one_screen
    page.evaluate_script(<<~JS)
      (() => {
        const root = document.documentElement
        window.scrollTo(0, root.scrollHeight)
        const box = (selector) => { const b = document.querySelector(selector).getBoundingClientRect(); return { top: b.top, bottom: b.bottom, height: b.height } }
        return { scrollable: root.scrollHeight > root.clientHeight, scrollY: window.scrollY, height: window.innerHeight,
                 top: box(".c-scan__top"), stage: box(".c-scan__stage"), bottom: box(".c-scan__bottom"), main: box(".c-scan__main") }
      })()
    JS
  end

  # Asserts the page in the frame is one screen of viewport_height: no scroll, the bars at the viewport's edges, the stage
  # between them and the main button inside (spec 082 AC-1.1, AC-1.2).
  #
  # @param viewport_height [Integer] the height the page should fill
  def expect_one_screen(viewport_height)
    measures = one_screen
    expect(measures["scrollable"]).to be(false)
    expect(measures["scrollY"]).to eq(0)
    expect(measures["top"]["top"]).to eq(0)
    expect(measures["height"]).to eq(viewport_height)
    expect(measures["bottom"]["bottom"]).to be_within(0.5).of(viewport_height)
    expect(measures["stage"]["top"]).to be_within(0.5).of(measures["top"]["bottom"])
    expect(measures["stage"]["bottom"]).to be_within(0.5).of(measures["bottom"]["top"])
    expect(measures["main"]["bottom"]).to be <= viewport_height
  end

  # Holds the next reading's request until window.__release() is called, so the reading state can be measured.
  def hold_readings
    page.execute_script("const send = window.fetch; window.fetch = (url, options) => url.includes('/scanner/readings') ? new Promise((resolve) => { window.__release = () => resolve(send(url, options)) }) : send(url, options)")
  end

  # Opens the destination sheet, as the collector's tap on the top bar does.
  def open_destination = find(".c-scan__dest").click

  # Opens the sitting's list sheet from the count.
  def open_sitting_list = find("#scanner_count").click
end

RSpec.configure { |config| config.include ScannerHelpers, type: :system }
