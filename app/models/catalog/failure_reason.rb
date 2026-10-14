# Why a refresh or an operation failed, in plain words for the admin catalog page (issue #84), from the message its
# record stored. A failed run or build stores its error as "<error class>: <error message>"; the page shows the
# sentence for that class, and that stored text only as the technical detail beside it (for a bug report).
# `catalog:status` and the log keep printing the stored text as it is.
#
# The sentence is worked out each time it is shown, not stored, so runs that failed before this existed read the
# same way, and the stored text stays the one record of what went wrong.
#
# The core words the failures every source shares (Catalog::Sources' errors, a busy database); a source words its own
# through the optional .failure_reasons hook (app/models/catalog/sources.rb). Anything else gets GENERIC.
class Catalog::FailureReason
  REASONS = {
    "Catalog::Sources::RateLimitedError" =>
      "The source was turning requests away for a while (rate limiting). Nothing is wrong on your side.",
    "Catalog::Sources::TransientError" =>
      "The source couldn't be reached, or answered with an error. This usually passes by itself.",
    "Catalog::Sources::IntegrityError" =>
      "The download couldn't be verified: it didn't match what the source published, so none of it was applied.",
    "SQLite3::BusyException" => "The database was busy and didn't answer in time. This usually passes by itself.",
    # What Active Record raises for SQLite3::BusyException.
    "ActiveRecord::StatementTimeout" => "The database was busy and didn't answer in time. This usually passes by itself."
  }.freeze
  GENERIC = "An unexpected error stopped it.".freeze
  # "Some::Error: what it said": a constant path, a colon and a space.
  ERROR_TEXT = /\A(?<error>[A-Z]\w*(?:::[A-Z]\w*)*): /

  attr_reader :message

  # The type's source supplies wording for its own errors through the optional .failure_reasons hook.
  def self.for(message, collectible_type)
    source = Catalog.source_class(collectible_type)
    new(message, reasons: source.respond_to?(:failure_reasons) ? source.failure_reasons : {})
  end

  def initialize(message, reasons: {})
    @message = message.to_s.strip
    @reasons = REASONS.merge(reasons.to_h)
  end

  # A message that isn't an error's ("interrupted") is kept, as a sentence.
  def sentence
    return @reasons.fetch(error, GENERIC) if detail
    return GENERIC if message.empty?

    message.upcase_first.then { it.end_with?(".") ? it : "#{it}." }
  end

  # The stored error text, or nil when the message isn't an error's.
  def detail = (message if error)

  private
    def error = message[ERROR_TEXT, :error]
end
