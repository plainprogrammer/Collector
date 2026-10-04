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
    window.__syntheticCard = async (name, lines) => {
      const { guideRect } = await window.__geometry
      const canvas = Object.assign(document.createElement("canvas"), { width: 900, height: 1200 })
      const context = canvas.getContext("2d")
      const card = guideRect(canvas.width, canvas.height)
      // Text is sized and placed from the card, as on a real card, so strip tuning doesn't change the test text.
      const draw = () => {
        context.fillStyle = "gray"; context.fillRect(0, 0, canvas.width, canvas.height)
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

  # What the shipped detector finds in a grey photo with a white card-shaped rectangle, optionally tilted. noise adds
  # seeded sensor noise of up to that many levels: on a perfectly flat picture over half the edge strengths are 0, so the
  # detector's edge threshold is 0 and every flat pixel votes for a horizontal line (as in the spike).
  def detect_synthetic(card:, width: 1200, height: 1600, tilt_degrees: 0, noise: 0)
    page.evaluate_async_script(<<~JS, width, height, card, tilt_degrees, noise)
      const [ width, height, card, tilt, noise, done ] = arguments
      #{MODULES_JS}
      window.__modules.then(({ detector }) => {
        const canvas = Object.assign(document.createElement("canvas"), { width, height })
        const context = canvas.getContext("2d")
        context.fillStyle = "#555"; context.fillRect(0, 0, width, height)
        if (card) {
          context.translate(card.x + card.width / 2, card.y + card.height / 2); context.rotate(tilt * Math.PI / 180)
          context.fillStyle = "white"; context.fillRect(-card.width / 2, -card.height / 2, card.width, card.height)
        }
        if (noise > 0) {
          const image = context.getImageData(0, 0, width, height)
          let seed = 1
          for (let i = 0; i < image.data.length; i += 4) {
            seed = (seed * 16807) % 2147483647
            for (let channel = 0; channel < 3; channel++) image.data[i + channel] += (seed % (2 * noise + 1)) - noise
          }
          context.putImageData(image, 0, 0)
        }
        const found = detector.findCard(canvas)
        done({ found: found.found, corners: found.corners || null, picture: found.picture ? [ found.picture.width, found.picture.height ] : null })
      })
    JS
  end

  # Picks a photo of a synthetic card drawn anywhere in it (or none), so the detector rather than the guide has to find it.
  def pick_photo(card: { x: 40, y: 360, width: 859, height: 1200 }, width: 1200, height: 1600, name: "Lightning Bolt", lines: [ "R 0123", "MOM • EN" ])
    page.evaluate_async_script(<<~JS, width, height, card, name, lines)
      const [ width, height, card, name, lines, done ] = arguments
      #{CARD_JS}
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
      canvas.toBlob((blob) => {
        const transfer = new DataTransfer()
        transfer.items.add(new File([ blob ], "card.png", { type: "image/png" }))
        const input = document.querySelector("[data-card-reader-target=picker]")
        input.files = transfer.files
        input.dispatchEvent(new Event("change", { bubbles: true }))
        done(true)
      }, "image/png")
    JS
  end

  def show_synthetic_card(name: "Lightning Bolt", lines: [ "R 0123", "MOM • EN" ], torch: false)
    page.evaluate_async_script(<<~JS, name, lines, torch)
      const [ name, lines, torch, done ] = arguments
      #{CARD_JS}
      window.__syntheticCard(name, lines).then(({ canvas, draw }) => {
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
    eventually("window.__tracks.length > 0 && document.querySelector('.c-scanner__video').readyState >= 2")
  end

  # The engine has loaded and a live camera feed is showing (the shutter enables only then).
  def wait_for_scanner
    expect(page).to have_button("Capture", disabled: false, wait: 30)
  end

  def pick_synthetic_photo(name: "Lightning Bolt", lines: [ "R 0123", "MOM • EN" ])
    page.evaluate_async_script(<<~JS, name, lines)
      const [ name, lines, done ] = arguments
      #{CARD_JS}
      window.__syntheticCard(name, lines).then(({ canvas }) => canvas.toBlob((blob) => {
        const transfer = new DataTransfer()
        transfer.items.add(new File([ blob ], "card.png", { type: "image/png" }))
        const input = document.querySelector("[data-card-reader-target=picker]")
        input.files = transfer.files
        input.dispatchEvent(new Event("change", { bubbles: true }))
        done(true)
      }, "image/png"))
    JS
  end

  def restart_camera
    page.execute_script(%(window.Stimulus.getControllerForElementAndIdentifier(document.querySelector(".c-scanner"), "camera").restart()))
  end

  # Waits for a JavaScript expression to become truthy, the way Capybara's matchers wait for the DOM.
  def eventually(script, wait: 10)
    page.document.synchronize(wait) { page.evaluate_script(script) || raise(Capybara::ExpectationNotMet, script) }
  end

  def scanner_sent = page.evaluate_script("window.__sent")
end

RSpec.configure { |config| config.include ScannerHelpers, type: :system }
