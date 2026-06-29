# typed: false
# frozen_string_literal: true

class OtpTelephoneDeliveryAdapter < OtpDeliveryAdapter
  def deliver(record:, otp_code:, **)
    SignTelephoneOtpDelivery.deliver!(record, otp_code)
  end
end
