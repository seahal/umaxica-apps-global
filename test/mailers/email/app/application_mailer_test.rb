# typed: false
# frozen_string_literal: true

# rubocop:disable Rails/I18nLocaleTexts

require "test_helper"
# require "helpers/global_test_support"

class Email::App::ApplicationMailerTest < ActionMailer::TestCase
  test "sets promotional unsubscribe headers when requested" do
    email_record = ClientEmail.new(public_id: "email_public_id")
    original_base_service_url = ENV["BASE_SERVICE_URL"]
    ENV["BASE_SERVICE_URL"] = "www.app.localhost"

    mailer =
      Class.new(Email::App::ApplicationMailer) do
        define_method(:sample) do
          set_promotional_unsubscribe_headers(params.fetch(:email_record))
          mail(to: "client@example.com", subject: "Client Sample") do |format|
            format.text { render plain: "hello" }
          end
        end
      end

    email = mailer.with(email_record: email_record).sample
    expected_url = Rails.application.routes.url_helpers.base_app_preference_email_url(
      email_record,
      token: email_record.promotional_unsubscribe_token,
      host: ENV.fetch("BASE_SERVICE_URL"),
    )

    assert_equal "<#{expected_url}>", email["List-Unsubscribe"].value
    assert_equal "List-Unsubscribe=One-Click", email["List-Unsubscribe-Post"].value
  ensure
    ENV["BASE_SERVICE_URL"] = original_base_service_url
  end
end

# rubocop:enable Rails/I18nLocaleTexts
