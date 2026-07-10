# typed: false
# frozen_string_literal: true

class NoticeEmailAdapter < NoticeAdapter
  def initialize(mailer)
    super()
    @mailer = mailer
  end

  def deliver(email_address:, title:, body:, **)
    @mailer.with(
      email_address: email_address,
      title: title,
      body: body,
    ).notice.deliver_later
  end
end
