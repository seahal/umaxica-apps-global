# typed: false
# frozen_string_literal: true

class OutboundSms < ApplicationService
  PROVIDERS = {
    "aws_sns" => OutboundSmsProvidersAwsSns,
    "test" => OutboundSmsProvidersTest,
  }.freeze

  SUSPENDED_ERROR = "outbound sms channel is suspended"

  def self.deliver_now(to:, title:, body:)
    return suspended_result if suspended?

    provider.send_message(to: to, title: title, body: body)
  end

  def self.deliver_later(to:, title:, body:)
    return suspended_result if suspended?

    provider
    Outbound::SmsDeliveryJob.perform_later(
      to: to,
      title: title,
      encrypted_body: OutboundSensitivePayload.encrypt_sms_body(body),
    )
    OutboundResult.accepted(channel: :sms)
  end

  def self.suspended?
    OutboundChannelSuspension.suspended?(:sms)
  end

  # The recipient is not logged: the outcome and the channel are what an operator needs
  # while the kill switch is pulled.
  def self.suspended_result
    Rails.logger.warn(JitLogEvent.format("outbound.sms.suspended", channel: "sms"))
    OutboundResult.rejected(channel: :sms, error: SUSPENDED_ERROR)
  end

  def self.provider
    provider_name = Rails.application.config.sms_provider.to_s
    provider_class =
      PROVIDERS.fetch(provider_name) do
        raise ArgumentError, "Unknown SMS provider: #{provider_name}"
      end

    provider_class.new
  end

  def initialize(to:, title:, body:, **options)
    super()
    @to = to
    @title = title
    @body = body
    @options = options
  end

  def call
    self.class.deliver_later(to: to, title: title, body: body)
  end

  private

  attr_reader :to, :title, :body, :options
end
