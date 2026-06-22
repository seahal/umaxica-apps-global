# typed: false
# frozen_string_literal: true

module Email::Org
  class ApplicationMailer < ActionMailer::Base
    include PromotionalEmailUnsubscribeHeaders
    include SafePromotionalCtaUrl

    default from: Rails.app.creds.option(:smtp_from_address_org, default: "from@umaxica.org")
    layout "mailer/org/mailer"
  end
end
