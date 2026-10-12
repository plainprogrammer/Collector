# The content notices in every page's footer (spec 018): what each catalog type's source asks to be said about its
# content, and where its data comes from. A source supplies its lines through the optional .content_notice hook
# (app/models/catalog/sources.rb). The core shows them in order and knows nothing of what they say or link to.
module Catalog::ContentNotice
  # One line of a notice: plain text, and the phrases of it that are links ({ "phrase" => "https://…" }).
  Line = Data.define(:text, :links) do
    def initialize(text:, links: {})
      # String.new: a phrase a source marked html_safe is still plain text here, so the view escapes it.
      super(text: text.to_s.strip, links: links.to_h.to_h { |phrase, address| [ String.new(phrase.to_s), String.new(address.to_s) ] }.freeze)
    end

    # The line in reading order as [text, address] parts, the address nil where the text isn't a link. A line with a
    # link that breaks a rule (FR-1) is one part of plain text.
    def parts
      return [ [ text, nil ] ] unless linked?

      cursor = 0
      linked = spans.flat_map do |start, phrase, address|
        before = text[cursor...start]
        cursor = start + phrase.length
        [ [ before, nil ], [ phrase, address ] ]
      end
      (linked << [ text[cursor..], nil ]).reject { |part, _| part.empty? }
    end

    private
      # Every phrase occurs exactly once, no two overlap, and every address is an absolute https URI.
      def linked?
        links.any? && links.all? { |phrase, address| once?(phrase) && https?(address) } &&
          spans.each_cons(2).all? { |(start, phrase, _), (following, _, _)| start + phrase.length <= following }
      end

      def spans = links.map { |phrase, address| [ text.index(phrase), phrase, address ] }.sort_by(&:first)

      def once?(phrase) = phrase.present? && text.index(phrase).present? && text.index(phrase) == text.rindex(phrase)

      def https?(address)
        uri = URI.parse(address)
        uri.is_a?(URI::HTTPS) && uri.host.present?
      rescue URI::InvalidURIError
        false
      end
  end

  # Every registered type's lines: types in registration order, each type's lines in the order its source gives
  # them, a repeated line (the same text and links) once, where it first appears. No query, no I/O.
  def self.lines
    Catalog.sources.each_value.flat_map { |name| lines_of(name.constantize) }.reject { |line| line.text.empty? }.uniq
  end

  def self.lines_of(source) = source.respond_to?(:content_notice) ? Array(source.content_notice) : []
  private_class_method :lines_of
end
