# typed: false
# frozen_string_literal: true

# Routes ordinary notice delivery to the appropriate channel adapter.
class NoticeAdapter
  def self.for(surface:, channel:)
    case [surface.to_sym, channel.to_sym]
    when [:app, :email] then NoticeEmailAdapter.new(Email::App::AlertMailer)
    when [:com, :email] then NoticeEmailAdapter.new(Email::Com::AlertMailer)
    when [:org, :email] then NoticeEmailAdapter.new(Email::Org::AlertMailer)
    else
      raise ArgumentError, "Unknown notice delivery channel: #{surface}/#{channel}"
    end
  end

  def deliver(**)
    raise NotImplementedError, "#{self.class}#deliver is not implemented"
  end
end
