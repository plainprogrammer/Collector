# The add page's form (spec 068 decision 3): the text of Finish and Quantity as typed, checked, then written through
# `Deck::Proxy.add!`. A sentence lands on the field it belongs to; what was typed stays for the page to show again.
class Deck::Proxy::Addition
  include ActiveModel::Model
  include ActiveModel::Attributes

  QUANTITY_SENTENCE = "Enter a number from 1 to 9,999.".freeze

  attribute :finish, :string
  attribute :quantity, :string, default: "1"
  attr_accessor :account, :zone, :entry

  # @return [Deck::Proxy, nil] the proxy {#save} wrote or merged into
  attr_reader :proxy

  # Checks and writes.
  #
  # @return [Boolean] false, with a sentence on `errors[:quantity]` or `errors[:finish]`, when nothing was written
  def save
    errors.clear
    count = Deck::Proxy.parse_quantity(quantity)
    unless count
      errors.add(:quantity, QUANTITY_SENTENCE)
      return false
    end

    @proxy = Deck::Proxy.add!(account:, zone:, entry:, finish: finish.presence, quantity: count)
    true
  rescue ActiveRecord::RecordInvalid => error
    error.record.errors.each { |message| errors.add(message.attribute == :entry || message.attribute == :zone ? :base : message.attribute, message.message) }
    false
  end
end
