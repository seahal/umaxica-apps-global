# typed: false
# frozen_string_literal: true

module Email::Org
  class AlertMailer < ApplicationMailer
    default from: "alert@umaxica.org"

    def notice
      @title = params.fetch(:title)
      @body = params.fetch(:body)

      mail(to: params.fetch(:email_address), subject: @title)
    end
  end
end
