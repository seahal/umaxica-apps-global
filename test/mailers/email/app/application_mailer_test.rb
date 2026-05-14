# typed: false
# frozen_string_literal: true

require "test_helper"

class Email::App::ApplicationMailerTest < ActionMailer::TestCase
  test "sets promotional unsubscribe headers when requested" do
    email_record = UserEmail.new(public_id: "email_public_id")

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
    expected_url = Rails.application.routes.url_helpers.sign_app_preference_email_url(
      email_record,
      token: email_record.promotional_unsubscribe_token,
      host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
    )

    assert_equal "<#{expected_url}>", email["List-Unsubscribe"].value
    assert_equal "List-Unsubscribe=One-Click", email["List-Unsubscribe-Post"].value
  end
end
