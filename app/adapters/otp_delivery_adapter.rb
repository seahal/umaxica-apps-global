# typed: false
# frozen_string_literal: true

# Routes OTP delivery to the appropriate channel adapter based on surface and channel.
class OtpDeliveryAdapter
  def self.for(surface:, channel:)
    case [surface.to_sym, channel.to_sym]
    when [:app, :email]                then OtpEmailDeliveryAdapter.new(Email::App::OtpMailer)
    when [:com, :email]                then OtpEmailDeliveryAdapter.new(Email::Com::OtpMailer)
    when [:org, :email]                then OtpEmailDeliveryAdapter.new(Email::Org::OtpMailer)
    when [:app, :telephone],
         [:com, :telephone] then OtpTelephoneDeliveryAdapter.new
    else
      raise ArgumentError, "Unknown OTP delivery channel: #{surface}/#{channel}"
    end
  end

  def deliver(**)
    raise NotImplementedError, "#{self.class}#deliver is not implemented"
  end
end
