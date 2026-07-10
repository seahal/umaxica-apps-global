# typed: false
# frozen_string_literal: true

module Email::Com
  class AlertMailer < ApplicationMailer
    default from: "alert@umaxica.com"

    def notice
      @title = params.fetch(:title)
      @body = params.fetch(:body)

      mail(to: params.fetch(:email_address), subject: @title)
    end
  end
end
