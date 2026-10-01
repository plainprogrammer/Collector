# The card scanner's Content Security Policy (spec 007 AC-2.4, ADR 0001), for every page that loads the OCR
# engine: scripts, workers and connections only from this origin, plus blob: for the engine's worker,
# 'wasm-unsafe-eval' to compile it and a per-request nonce for the page's inline tags. Images may also come
# from the hosts catalog pages already use for card images. Other pages send no policy (AC-2.3).
module ScannerPage
  extend ActiveSupport::Concern

  included do
    content_security_policy do |policy|
      policy.default_src :self
      policy.script_src :self, :wasm_unsafe_eval
      policy.worker_src :self, :blob
      policy.connect_src :self
      policy.img_src :self, :data, :blob, *Catalog.allowed_hosts.map { "https://#{it}" }
      policy.style_src :self, :unsafe_inline
      policy.font_src :self
      policy.object_src :none
      policy.frame_src :none
      policy.base_uri :self
      policy.form_action :self
      policy.frame_ancestors :self
    end
  end
end
