# typed: false
# frozen_string_literal: true

module Outbound
  class Sms < ApplicationService
    PROVIDERS = {
      "aws_sns" => Outbound::SmsProviders::AwsSns,
      "test" => Outbound::SmsProviders::Test,
    }.freeze

    def self.deliver_now(to:, title:, body:)
      provider.send_message(to: to, title: title, body: body)
    end

    def self.deliver_later(to:, title:, body:)
      provider
      Outbound::SmsDeliveryJob.perform_later(
        to: to,
        title: title,
        encrypted_body: Outbound::SensitivePayload.encrypt_sms_body(body),
      )
      Result.accepted(channel: :sms)
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
end
