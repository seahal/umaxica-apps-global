# typed: false
# frozen_string_literal: true

# rubocop:disable Rails/I18nLocaleTexts

require "test_helper"

class Email::Com::ApplicationMailerTest < ActionMailer::TestCase
  test "applies default from address" do
    expected_from = "from@umaxica.com"

    assert_equal expected_from, Email::Com::ApplicationMailer.default[:from]

    mailer =
      Class.new(Email::Com::ApplicationMailer) do
        define_method(:sample) do
          mail(
            to: "com-user@example.com",
            subject: I18n.t("test.email.com.application_mailer.subject"),
          ) do |format|
            format.text { render plain: "hello" }
          end
        end
      end

    I18n.backend.store_translations(
      :en,
      { test: { email: { com: { application_mailer: { subject: "Com Sample" } } } } },
    )
    email = mailer.new.sample

    assert_equal [expected_from], email.from
    assert_equal ["com-user@example.com"], email.to
    assert_equal I18n.t("test.email.com.application_mailer.subject"), email.subject
    assert_equal "hello", email.body.encoded
  end

  test "uses corporate mailer layout" do
    assert_equal "mailer/com/mailer", Email::Com::ApplicationMailer._layout
  end

  test "sets promotional unsubscribe headers when requested" do
    visitor = create_verified_visitor_with_email(email_address: "mailer-visitor-#{SecureRandom.hex(4)}@example.com")
    email_record = visitor.visitor_emails.first

    mailer =
      Class.new(Email::Com::ApplicationMailer) do
        define_method(:sample) do
          set_promotional_unsubscribe_headers(params.fetch(:email_record))
          mail(to: "visitor@example.com", subject: "Visitor Sample") do |format|
            format.text { render plain: "hello" }
          end
        end
      end

    email = mailer.with(email_record: email_record).sample
    expected_url = Rails.application.routes.url_helpers.base_com_preference_email_url(
      email_record,
      token: email_record.promotional_unsubscribe_token,
      host: ENV.fetch("PRIVATE_ACME_CORPORATE_URL", "www.com.localhost"),
    )

    assert_equal "<#{expected_url}>", email["List-Unsubscribe"].value
    assert_equal "List-Unsubscribe=One-Click", email["List-Unsubscribe-Post"].value
  end
end

# rubocop:enable Rails/I18nLocaleTexts
