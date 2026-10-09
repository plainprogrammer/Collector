# Loads the page's own scanner/art module into the WebDriver sandbox, as ScannerHelpers::MODULES_JS loads geometry
# (spec 011 Story 5, Story 8).
module ArtPageHelpers
  ART_JS = <<~JS.freeze
    window.__art ||= new Promise((resolve) => {
      addEventListener("art-ready", () => resolve(window.__scannerArt), { once: true })
      const script = Object.assign(document.createElement("script"), { type: "module", nonce: document.querySelector("script[type=importmap]")?.nonce || "" })
      script.textContent = `import * as art from "scanner/art"; window.__scannerArt = art; dispatchEvent(new Event("art-ready"))`
      document.head.append(script)
    })
  JS

  # Runs `body` with `art` (the module) and `args` in scope; `body` calls done(result).
  def run_art_js(body, *args)
    page.evaluate_async_script(<<~JS, *args)
      const args = Array.from(arguments).slice(0, -1), done = arguments[arguments.length - 1]
      #{ART_JS}
      window.__art.then((art) => { #{body} })
    JS
  end

  # The page's six fingerprints (hex) of a PNG drawn at its own size, as the build fingerprints a whole small image.
  def browser_fingerprints(png, settings: MTG::Art::Settings.fingerprint)
    run_art_js(<<~JS, Base64.strict_encode64(png), settings)
      const [ data, settings ] = args
      const image = new Image()
      image.onload = () => {
        const canvas = Object.assign(document.createElement("canvas"), { width: image.naturalWidth, height: image.naturalHeight })
        canvas.getContext("2d").drawImage(image, 0, 0)
        done(art.fingerprints(canvas, settings).map(art.hex))
      }
      image.src = `data:image/png;base64,${data}`
    JS
  end
end

RSpec.configure { |config| config.include ArtPageHelpers, type: :system }
