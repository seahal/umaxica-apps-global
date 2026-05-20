# typed: false
# frozen_string_literal: true

module Email::App
  class AlertMailer < ApplicationMailer
    default from: "alert@umaxica.app"

    def notice
      @title = params.fetch(:title)
      @body = params.fetch(:body)

      mail(to: params.fetch(:email_address), subject: @title)
    end
  end
end
