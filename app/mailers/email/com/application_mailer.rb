# typed: false
# frozen_string_literal: true

module Email::Com
  class ApplicationMailer < ActionMailer::Base
    include PromotionalEmailUnsubscribeHeaders

    default from: ENV.fetch("SMTP_FROM_ADDRESS_COM", "from@umaxica.com")
    layout "mailer/com/mailer"
  end
end
