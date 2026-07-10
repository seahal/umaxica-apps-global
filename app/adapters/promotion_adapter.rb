# typed: false
# frozen_string_literal: true

# Routes promotional delivery to the appropriate channel adapter.
class PromotionAdapter
  def self.for(surface:, channel:)
    case [surface.to_sym, channel.to_sym]
    when [:app, :email] then PromotionEmailAdapter.new(Email::App::PromotionalMailer)
    when [:com, :email] then PromotionEmailAdapter.new(Email::Com::PromotionalMailer)
    when [:org, :email] then PromotionEmailAdapter.new(Email::Org::PromotionalMailer)
    else
      raise ArgumentError, "Unknown promotion delivery channel: #{surface}/#{channel}"
    end
  end

  def deliver(**)
    raise NotImplementedError, "#{self.class}#deliver is not implemented"
  end
end
