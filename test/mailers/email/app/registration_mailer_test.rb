# typed: false
# frozen_string_literal: true

require "test_helper"

class Email::App::RegistrationMailerTest < ActionMailer::TestCase
  test "create" do
    mail = Email::App::RegistrationMailer.with(hotp_token: "123456", email_address: "user@example.com").create

    assert_equal I18n.t("mail.email.app.registration_mailer.create.subject"), mail.subject
    assert_equal ["user@example.com"], mail.to
    assert_equal ["from@umaxica.app"], mail.from

    # Check for body content ensuring it contains the OTP code
    # We check decoded body because base64 encoding might differ
    assert_match "123456", mail.html_part.body.decoded
    assert_match "123456", mail.text_part.body.decoded
  end

  test "create with different hotp_token" do
    mail = Email::App::RegistrationMailer.with(hotp_token: "654321", email_address: "test@example.com").create

    assert_match "654321", mail.html_part.body.decoded
    assert_match "654321", mail.text_part.body.decoded
    assert_equal ["test@example.com"], mail.to
  end

  test "should set greeting instance variable from hotp_token" do
    mail = Email::App::RegistrationMailer.with(
      hotp_token: "999888",
      email_address: "greet@example.com",
    ).create

    assert_match "999888", mail.html_part.body.decoded
  end

  test "mail should have correct from address" do
    mail = Email::App::RegistrationMailer.with(hotp_token: "111111", email_address: "test@example.com").create

    assert_equal ["from@umaxica.app"], mail.from
  end
end
