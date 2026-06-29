# typed: false
# frozen_string_literal: true

module Email::App
  class ApplicationMailer < ActionMailer::Base
    include PromotionalEmailUnsubscribeHeaders
    include SafePromotionalCtaUrl

    default from: ENV.fetch("SMTP_FROM_ADDRESS_APP")
    layout "mailer/app/mailer"
  end
end
