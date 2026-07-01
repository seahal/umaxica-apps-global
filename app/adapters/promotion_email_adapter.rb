# typed: false
# frozen_string_literal: true

class PromotionEmailAdapter < PromotionAdapter
  def initialize(mailer)
    @mailer = mailer
  end

  def deliver(email_address:, title:, body:, cta_url: nil, email_record: nil, **)
    @mailer.with(
      email_address: email_address,
      title: title,
      body: body,
      cta_url: cta_url,
      email_record: email_record,
    ).notice.deliver_later
  end
end
