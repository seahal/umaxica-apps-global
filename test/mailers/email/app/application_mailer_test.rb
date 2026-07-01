# typed: false
# frozen_string_literal: true

# rubocop:disable Rails/I18nLocaleTexts

require "test_helper"
# require "helpers/global_test_support"

class Email::App::ApplicationMailerTest < ActionMailer::TestCase
  test "sets promotional unsubscribe headers when requested" do
    email_record = ClientEmail.new(public_id: "email_public_id")
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
      host: Rails.configuration.x.boot_config.fetch(:hosts).base_service.host,
    )

    assert_equal "<#{expected_url}>", email["List-Unsubscribe"].value
    assert_equal "List-Unsubscribe=One-Click", email["List-Unsubscribe-Post"].value
  end
end

# rubocop:enable Rails/I18nLocaleTexts
