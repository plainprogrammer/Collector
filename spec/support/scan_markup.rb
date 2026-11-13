# Markup of the phone-first scanner's parts (spec 080): the status band, the sheet, the one-screen shell and the selection
# pane. No view renders them yet (#344 and #345 build the views), so the examples that prove their CSS are written from
# these strings; a view that replaces a part takes its examples with it. The four previews under
# docs/design-system/previews were generated once from these strings and are edited by hand from now on, so a change here
# doesn't reach them. Plain Ruby with no Rails, so `ruby -r ./spec/support/scan_markup.rb` can print a part's markup for
# a document.
module ScanMarkup
  # The icons the parts draw: Lucide's paths in a 24px viewBox (README Iconography). The torch, the question mark and the
  # chevrons have no partial under app/views/icons yet.
  ICONS = {
    back: '<path d="m15 18-6-6 6-6"/>',
    forward: '<path d="m9 18 6-6-6-6"/>',
    down: '<path d="m6 9 6 6 6-6"/>',
    cross: '<path d="M18 6 6 18M6 6l12 12"/>',
    check: '<path d="M20 6 9 17l-5-5"/>',
    alert: '<path d="M12 4 2.5 20h19z"/><path d="M12 10v4M12 17h.01"/>',
    question: '<circle cx="12" cy="12" r="9"/><path d="M9.1 9a3 3 0 0 1 5.8 1c0 2-3 3-3 3M12 17h.01"/>',
    torch: '<path d="M13 2 3 14h9l-1 8 10-12h-9z"/>'
  }.freeze

  # The filled star of a special finish, as the star partial writes it (FinishBadge).
  STAR = '<svg viewBox="0 0 24 24" fill="currentColor" stroke="none" aria-hidden="true">' \
    '<path d="m12 2 3 6.5 7 .8-5.2 4.8 1.4 7L12 17.6 5.8 21.1l1.4-7L2 9.3l7-.8z"/></svg>'.freeze

  # The sample printing the examples and the previews vary (the mock-ups' copy, not catalog data).
  CARD = { name: "Lightning Bolt", set: "March of the Machine", code: "MOM · 123", year: "2023", finishes: %w[nonfoil foil] }.freeze

  # The status line's sentence while aiming.
  AIM = "Line the card up with the guide, then capture.".freeze

  module_function

  # An icon as the partials write it: stroke 1.5, hidden from assistive technology. The component's CSS sets its size.
  #
  # @param name [Symbol] a key of ICONS
  # @return [String] the `svg`
  def icon(name)
    %(<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">#{ICONS.fetch(name)}</svg>)
  end

  # The sample printing with some of its facts changed.
  #
  # @param changes [Hash] `name`, `set`, `code`, `year`, `finishes`
  # @return [Hash] a card for `pane`
  def sample_card(**changes) = CARD.merge(changes)

  # A status band (StatusBand): an icon and a sentence on a filled ground.
  #
  # @param form [Symbol] `:success` or `:warning`
  # @param sentence [String] the words
  # @param mark [Symbol] the icon; a check for success, the alert triangle for warning, `:question` for the unsure warning
  # @param id [String, nil] an id for an example to find it by
  # @return [String] the `p`
  def band(form, sentence, mark: (form == :success ? :check : :alert), id: nil)
    %(<p class="c-band c-band--#{form}" role="status"#{%( id="#{id}") if id}>#{icon(mark)}<span>#{sentence}</span></p>)
  end

  # The shell's top bar: Back, the sitting's destination, Done.
  #
  # @param value [String] the destination ("Atraxa › Main · NM", "No location")
  # @return [String] the bar
  def top_bar(value = "Atraxa › Main · NM")
    <<~HTML
      <div class="c-scan__top">
        <a class="c-scan__back" href="#" aria-label="Back">#{icon(:back)}</a>
        <button type="button" class="c-scan__dest"><span class="c-scan__dest-label">Adding to</span> <span class="c-scan__dest-value"><span class="c-scan__dest-text">#{value}</span>#{icon(:down)}</span></button>
        <a class="c-btn c-btn--ghost c-scan__done" href="#">Done</a>
      </div>
    HTML
  end

  # The two lines over the camera. Each keeps its `role="status"` element; the wrapper that draws the line carries
  # `hidden` while the other shows, and Undo sits outside the live region (spec 080 decision 17).
  #
  # @param status [String, nil] the status line's sentence; nil hides the line
  # @param added [String, nil] the after-add line's sentence; given, it takes the status line's place
  # @return [String] both wrappers
  def lines(status: AIM, added: nil)
    <<~HTML
      <div class="c-scan__line c-scan__line--status"#{" hidden" if added || status.nil?}><p class="c-scan__line-text" role="status">#{status unless added}</p></div>
      <div class="c-scan__line c-scan__line--added"#{" hidden" unless added}><p class="c-scan__line-text" role="status">#{added}</p><form class="c-scan__undo"><button type="button" class="c-btn c-btn--ghost">Undo</button></form></div>
    HTML
  end

  # The capture strip: the frozen capture, shrunk, and what was read from it.
  #
  # @param name [String] the name read
  # @param line [String] the collector line read, or "nothing read"
  # @param caption [String, nil] a preview's caption inside the picture
  # @return [String] the strip
  def strip(name: "Lightning Bolt", line: "MOM · 123 · EN", caption: nil)
    <<~HTML
      <div class="c-scan__strip">
        <div class="c-scan__capture">#{caption}</div>
        <div class="c-scan__read"><p class="c-scan__read-label">Read from the card</p><p class="c-scan__read-name">#{name}</p><p class="c-scan__read-line">#{line}</p></div>
      </div>
    HTML
  end

  # One add button, a `button_to`'s shape. Its accessible name is today's (spec 009); a special finish carries the star.
  #
  # @api private
  def add_button(card, finish, label)
    name = [ "Add", card[:name], card[:code], finish&.capitalize ].compact.join(" ")
    star = finish && finish != "nonfoil" ? STAR : ""
    %(<form class="c-scanpane__add"><button type="button" class="c-btn c-btn--secondary" aria-label="#{name}">#{star}#{label || (finish ? "Add #{finish}" : "Add")}</button></form>)
  end

  # One card's details-and-adds panel.
  #
  # @api private
  def panel(card, position:, hidden:, labels:)
    finishes = card.fetch(:finishes)
    adds = finishes.size > 1 ? finishes.map { |finish| add_button(card, finish, labels[finish]) }.join : add_button(card, nil, nil)
    <<~HTML
      <div class="c-scanpane__card"#{" hidden" if hidden}>
        <div class="c-scanpane__details">
          <h2 class="c-scanpane__name">#{card[:name]}</h2>
          <p class="c-scanpane__set">#{card[:set]}</p>
          <p class="c-scanpane__meta"><span class="c-tag">#{card[:code]}</span> <span>#{card[:year]}</span> <span class="c-scanpane__position">#{position}</span></p>
        </div>
        <div class="c-scanpane__adds">#{adds}</div>
      </div>
    HTML
  end

  # The selection pane: the band, the row with Previous and Next, and one panel per card with all but the centred one hidden.
  #
  # @param band [String] the band's markup (see `band`)
  # @param cards [Array<Hash>] the row's cards, in order (see `sample_card`)
  # @param current [Integer] the index of the centred card
  # @param total [Integer] the count the position names ("2 of 14"), which may be more than the cards rendered
  # @param noun [String] what the position counts: "printings" or "possible cards"
  # @param step [String] what Previous and Next move by: "printing" or "card"
  # @param caption [String, nil] a preview's caption inside each image
  # @param labels [Hash{String => String}] a finish's button label when it is not "Add" and its name
  # @return [String] the pane
  def pane(band:, cards:, current: 0, total: cards.size, noun: "printings", step: "printing", caption: nil, labels: {})
    items = cards.each_index.map { |index| %(<li class="c-scanpane__item"#{' aria-current="true"' if index == current}>#{caption}</li>) }.join
    panels = cards.each_with_index.map { |card, index| panel(card, position: "#{index + 1} of #{total} #{noun}", hidden: index != current, labels:) }.join
    <<~HTML
      <div class="c-scanpane">
        #{band}
        <div class="c-scanpane__body">
          <div class="c-scanpane__rowwrap">
            <ul class="c-scanpane__row">#{items}</ul>
            <button type="button" class="c-btn c-btn--secondary c-scanpane__nav c-scanpane__nav--prev" aria-label="Previous #{step}"#{" disabled" if current.zero?}>#{icon(:back)}</button>
            <button type="button" class="c-btn c-btn--secondary c-scanpane__nav c-scanpane__nav--next" aria-label="Next #{step}"#{" disabled" if current == cards.size - 1}>#{icon(:forward)}</button>
          </div>
          #{panels}
        </div>
      </div>
    HTML
  end

  # The shell's bottom bar: the sitting's count, the main button, the torch.
  #
  # @param count [Integer] the adds in the sitting
  # @param main [Symbol] `:capture`, `:reading` (Capture, disabled) or `:again` (Scan again)
  # @param torch [Boolean] whether the camera reports a torch
  # @return [String] the bar
  def bottom_bar(count: 12, main: :capture, torch: true)
    button = { capture: %(<button type="button" class="c-btn c-btn--primary c-scan__main">Capture</button>),
               reading: %(<button type="button" class="c-btn c-btn--primary c-scan__main" disabled>Capture</button>),
               again: %(<button type="button" class="c-btn c-btn--secondary c-scan__main">Scan again</button>) }.fetch(main)
    light = %(<button type="button" class="c-btn c-btn--secondary c-scan__torch" aria-label="Torch" aria-pressed="false">#{icon(:torch)}</button>)
    <<~HTML
      <div class="c-scan__bottom">
        <button type="button" class="c-btn c-btn--secondary c-scan__count" aria-label="#{count} added. Show this sitting's cards."><b>#{count}</b><span>added</span></button>
        #{button}
        #{light if torch}
      </div>
    HTML
  end

  # The one-screen shell. With a result it carries `c-scan--result`, which shows the capture strip and the pane.
  #
  # @param result [String, nil] the pane's markup (see `pane`), or nil for the live camera
  # @param main [Symbol, nil] the main button (see `bottom_bar`); Scan again with a result, Capture without
  # @param status [String] the status line's sentence
  # @param added [String, nil] the after-add line's sentence
  # @param count [Integer] the sitting's count
  # @param torch [Boolean] whether the torch is rendered
  # @param value [String] the destination
  # @param guide [String, nil] the guide's box as the camera controller sets it inline ("left:5px;top:80px;…")
  # @param caption [String, nil] a preview's caption inside the guide
  # @param read [Hash] `strip`'s arguments
  # @return [String] the shell
  def shell(result: nil, main: nil, status: AIM, added: nil, count: 12, torch: true, value: "Atraxa › Main · NM", guide: nil, caption: nil, read: {})
    <<~HTML
      <div class="c-scan#{" c-scan--result" if result}">
        #{top_bar(value)}
        <div class="c-scan__stage">
          <video class="c-scan__video" playsinline muted></video>
          <div class="c-scan__guide" aria-hidden="true"#{%( style="#{guide}") if guide}>#{caption}</div>
          #{lines(status: (status unless result), added:)}
          #{strip(**read) if result}
          #{result}
        </div>
        #{bottom_bar(count:, main: main || (result ? :again : :capture), torch:)}
      </div>
    HTML
  end

  # A sheet: a native dialog with a head (title, Close) and a body, the content notice's lines in its foot.
  #
  # @param title [String] the sheet's title
  # @param body [String] the body's markup
  # @param foot [Array<String>] the content notice's lines; none gives no foot
  # @param id [String] the dialog's id
  # @param open [Boolean] the `open` attribute (a preview's static sheet; a page opens it with `showModal()`)
  # @return [String] the `dialog`
  def sheet(title:, body:, foot: [], id: "sheet", open: false)
    notice = foot.empty? ? "" : %(<div class="c-sheet__foot">#{foot.map { |line| "<p>#{line}</p>" }.join}</div>)
    <<~HTML
      <dialog class="c-sheet" id="#{id}" aria-labelledby="#{id}_title"#{" open" if open}>
        <div class="c-sheet__head">
          <h2 class="c-sheet__title" id="#{id}_title">#{title}</h2>
          <form method="dialog" class="c-sheet__dismiss"><button class="c-btn c-btn--ghost c-sheet__close" aria-label="Close">#{icon(:cross)}</button></form>
        </div>
        <div class="c-sheet__body">#{body}#{notice}</div>
      </dialog>
    HTML
  end
end
