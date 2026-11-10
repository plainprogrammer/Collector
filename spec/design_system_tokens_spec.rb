require "rails_helper"

# Spec 057 AC-2.3: the Charts rule says fills and outlines hold 3:1 against the ground they sit on. The two tokens a chart
# draws with (`ink-muted` for fills, `line-strong` for outlines and hatching) are compared with the three surfaces in each
# block of tokens.css that defines colours, unrounded. A token change that breaks the floor fails here. tokens.css is
# code (generated from tokens.json); the design system's prose is not read by RSpec (.claude/rules/testing.md).
RSpec.describe "Design system tokens: the contrast floor (spec 057 AC-2.3)" do
  let(:css) { Rails.root.join("app/assets/stylesheets/collector/tokens.css").read }

  # The three blocks that define colours: the light one, the dark one and the dark one the OS preference selects.
  def block(name)
    pattern = {
      "light" => /^:root, \[data-theme="light"\] \{(.*?)^\}/m,
      "dark" => /^\[data-theme="dark"\] \{(.*?)^\}/m,
      "dark by preference" => /^  :root:not\(\[data-theme\]\) \{(.*?)^  \}/m
    }.fetch(name)
    css[pattern, 1]
  end

  def colours(text) = text.scan(/--([a-z-]+):\s*(#\h{6})\b/).to_h
  def linear(channel) = channel <= 0.03928 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4

  def luminance(hex)
    red, green, blue = hex.delete("#").scan(/../).map { linear(it.to_i(16) / 255.0) }
    0.2126 * red + 0.7152 * green + 0.0722 * blue
  end

  def ratio(one, other)
    light, dark = [ luminance(one), luminance(other) ].max, [ luminance(one), luminance(other) ].min
    (light + 0.05) / (dark + 0.05)
  end

  # Every [drawn token, surface, ratio] in one block's colours that is under 3:1.
  def below_floor(palette)
    %w[ink-muted line-strong].product(%w[surface surface-raised surface-sunken])
      .map { |drawn, surface| [ drawn, surface, ratio(palette.fetch(drawn), palette.fetch(surface)) ] }
      .select { |_drawn, _surface, value| value < 3.0 }
  end

  it "computes WCAG's contrast ratio", :aggregate_failures do
    expect(ratio("#000000", "#ffffff")).to be_within(0.001).of(21.0)
    expect(ratio("#777777", "#ffffff")).to be_within(0.01).of(4.48)
  end

  [ "light", "dark", "dark by preference" ].each do |name|
    it "holds 3:1 for ink-muted and line-strong on every surface in the #{name} block", :aggregate_failures do
      expect(block(name)).to be_present
      expect(below_floor(colours(block(name)))).to be_empty
    end
  end

  it "finds the lowest pair, line-strong on the light surface-sunken, at 3.010:1" do
    palette = colours(block("light"))
    expect(ratio(palette.fetch("line-strong"), palette.fetch("surface-sunken"))).to be_within(0.001).of(3.010)
  end

  it "flags a token that falls under the floor (the check can fail)" do
    palette = colours(block("light")).merge("line-strong" => "#b0a898")
    expect(below_floor(palette).map(&:first)).to include("line-strong")
  end
end
