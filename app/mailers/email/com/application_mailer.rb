# typed: false
# frozen_string_literal: true

module Email::Com
  class ApplicationMailer < ActionMailer::Base
    include PromotionalEmailUnsubscribeHeaders
    include SafePromotionalCtaUrl

    default from: Rails.app.creds.option(:smtp_from_address_com, default: "from@umaxica.com")
    layout "mailer/com/mailer"
  end
end
