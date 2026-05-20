# typed: false
# frozen_string_literal: true

require "aws-sdk-sns"

module Outbound
  class SmsDeliveryJob < ApplicationJob
    queue_as :default

    retry_on Aws::SNS::Errors::ServiceError, wait: :polynomially_longer, attempts: 5
    retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 3
    retry_on Net::ReadTimeout, wait: :polynomially_longer, attempts: 3

    discard_on ArgumentError

    def perform(to:, title:, encrypted_body: nil, body: nil)
      raise ArgumentError, "Plaintext SMS job payload is no longer accepted" if encrypted_body.blank? && body.present?

      body = Outbound::SensitivePayload.decrypt_sms_body(encrypted_body)

      Sms.deliver_now(to: to, title: title, body: body)
    end
  end
end
