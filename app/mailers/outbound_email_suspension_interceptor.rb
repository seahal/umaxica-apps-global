# typed: false
# frozen_string_literal: true

# Stops outbound mail while the matching OutboundChannelSuspension kill switch is on.
#
# Registered as an ActionMailer interceptor (config/initializers/outbound_email.rb) rather
# than added to each mailer, so a new mailer cannot be added outside the switch.
class OutboundEmailSuspensionInterceptor
  PROMOTIONAL_MAILER_SUFFIX = "::PromotionalMailer"

  def self.delivering_email(message)
    channel = channel_for(message)
    return unless OutboundChannelSuspension.suspended?(channel)

    message.perform_deliveries = false
    # Telemetry only. Neither recipients nor the body are logged; the durable record of
    # the suspension is the feature flag itself.
    Rails.logger.warn(
      JitLogEvent.format(
        "outbound.email.suspended",
        channel: channel,
        mailer: message.delivery_handler&.name,
      ),
    )
  end

  def self.channel_for(message)
    mailer = message.delivery_handler&.name.to_s
    mailer.end_with?(PROMOTIONAL_MAILER_SUFFIX) ? :promotional_email : :email
  end
  private_class_method :channel_for
end
