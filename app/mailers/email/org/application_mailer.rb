# typed: false
# frozen_string_literal: true

module Email::Org
  class ApplicationMailer < ActionMailer::Base
    include PromotionalEmailUnsubscribeHeaders
    include SafePromotionalCtaUrl

    default from: ENV.fetch("SMTP_FROM_ADDRESS_ORG", "from@umaxica.org")
    layout "mailer/org/mailer"
  end
end
