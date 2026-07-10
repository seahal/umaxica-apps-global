# typed: false
# frozen_string_literal: true

module Email::Com
  class PromotionalMailer < ApplicationMailer
    default from: "promotion@umaxica.com"

    def notice
      @title = params.fetch(:title)
      @body = params.fetch(:body)
      @cta_url = safe_promotional_cta_url(params[:cta_url])
      email_record = params[:email_record]
      set_promotional_unsubscribe_headers(email_record) if email_record.present?

      mail(to: params.fetch(:email_address), subject: @title)
    end
  end
end
