# typed: false
# frozen_string_literal: true

# Routes OTP delivery to the appropriate channel adapter based on surface and channel.
#
# The email branches consult OtpEmailNotifierRollout, which is the single place
# the Noticed migration is switched. Every OTP call site already passes through
# here, so no call site knows which delivery path it got. See
# adr/notification-orchestration-via-noticed.md.
class OtpAdapter
  def self.for(surface:, channel:)
    case [surface.to_sym, channel.to_sym]
    when [:app, :email] then email_adapter(:app, Email::App::OtpMailer, Notify::App::OtpNotifier)
    when [:com, :email] then email_adapter(:com, Email::Com::OtpMailer, Notify::Com::OtpNotifier)
    when [:org, :email] then email_adapter(:org, Email::Org::OtpMailer, Notify::Org::OtpNotifier)
    when [:app, :telephone],
         [:com, :telephone],
         [:org, :telephone] then OtpTelephoneAdapter.new
    else
      raise ArgumentError, "Unknown OTP delivery channel: #{surface}/#{channel}"
    end
  end

  def self.email_adapter(surface, mailer, notifier)
    return OtpEmailNotifierAdapter.new(notifier) if OtpEmailNotifierRollout.enabled?(surface)

    OtpEmailAdapter.new(mailer)
  end
  private_class_method :email_adapter

  def deliver(**)
    raise NotImplementedError, "#{self.class}#deliver is not implemented"
  end
end
