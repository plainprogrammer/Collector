# Drives the scanner page in system specs (spec 007; ADR 0002): a synthetic 63:88 card, drawn so its name and
# collector line sit exactly where the page cuts its strips, stands in for the camera or a picked photo.
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
      const { STRIPS, guideRect } = await window.__geometry
      const canvas = Object.assign(document.createElement("canvas"), { width: 900, height: 1200 })
      const context = canvas.getContext("2d")
      const card = guideRect(canvas.width, canvas.height)
      const box = (strip) => ({ x: card.x + card.width * strip.x, y: card.y + card.height * strip.y, w: card.width * strip.w, h: card.height * strip.h })
      const draw = () => {
        context.fillStyle = "gray"; context.fillRect(0, 0, canvas.width, canvas.height)
        context.fillStyle = "white"; context.fillRect(card.x, card.y, card.width, card.height)
        context.fillStyle = "black"; context.textBaseline = "middle"
        const title = box(STRIPS.name)
        context.font = `${Math.round(title.h * 0.55)}px sans-serif`
        context.fillText(name, title.x + title.h * 0.2, title.y + title.h / 2)
        const footer = box(STRIPS.collector)
        context.font = `${Math.round(footer.h * 0.3)}px sans-serif`
        lines.forEach((line, index) => context.fillText(line, footer.x + footer.h * 0.2, footer.y + footer.h * (index + 1) / (lines.length + 1)))
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
