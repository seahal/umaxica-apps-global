# typed: false
# frozen_string_literal: true

# Routes OTP delivery to the appropriate channel adapter based on surface and channel.
class OtpAdapter
  def self.for(surface:, channel:)
    case [surface.to_sym, channel.to_sym]
    when [:app, :email]                then OtpEmailAdapter.new(Email::App::OtpMailer)
    when [:com, :email]                then OtpEmailAdapter.new(Email::Com::OtpMailer)
    when [:org, :email]                then OtpEmailAdapter.new(Email::Org::OtpMailer)
    when [:app, :telephone],
         [:com, :telephone],
         [:org, :telephone] then OtpTelephoneAdapter.new
    else
      raise ArgumentError, "Unknown OTP delivery channel: #{surface}/#{channel}"
    end
  end

  def deliver(**)
    raise NotImplementedError, "#{self.class}#deliver is not implemented"
  end
end
