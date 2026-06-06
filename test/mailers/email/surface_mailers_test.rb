# typed: false
# frozen_string_literal: true

# rubocop:disable Rails/I18nLocaleTexts

require "test_helper"

class Email::SurfaceMailersTest < ActionMailer::TestCase
  include ActiveJob::TestHelper

  test "app otp mailer sends verification code from app sender" do
    mail = Email::App::OtpMailer.with(
      encrypted_hotp_token: encrypted_otp("123456"),
      email_address: "user@example.com",
      public_id: "email-public-id",
      verification_token: "verification-token",
    ).create

    assert_equal I18n.t("mail.email.app.otp_mailer.create.subject"), mail.subject
    assert_equal ["user@example.com"], mail.to
    assert_equal ["otp@umaxica.app"], mail.from
    assert_match "123456", mail.html_part.body.decoded
    assert_match "verification-token", mail.html_part.body.decoded
  end

  test "com otp mailer sends verification code from com sender" do
    mail = Email::Com::OtpMailer.with(
      encrypted_hotp_token: encrypted_otp("654321"),
      email_address: "visitor@example.com",
    ).create

    assert_equal I18n.t("mail.email.com.otp_mailer.create.subject"), mail.subject
    assert_equal ["visitor@example.com"], mail.to
    assert_equal ["otp@umaxica.com"], mail.from
    assert_match "654321", mail.text_part.body.decoded
  end

  test "org otp mailer sends verification code from org sender" do
    mail = Email::Org::OtpMailer.with(
      encrypted_hotp_token: encrypted_otp("999888"),
      email_address: "operator@example.com",
    ).create

    assert_equal I18n.t("mail.email.org.otp_mailer.create.subject"), mail.subject
    assert_equal ["operator@example.com"], mail.to
    assert_equal ["otp@umaxica.org"], mail.from
    assert_match "999888", mail.text_part.body.decoded
  end

  test "otp mailers build verification links for their own surface" do
    [
      [Email::App::OtpMailer, "mail-app-public-id", "app-token", ENV.fetch("ID_SERVICE_URL", "id.umaxica.app")],
      [Email::Com::OtpMailer, "mail-com-public-id", "com-token", ENV.fetch("ID_CORPORATE_URL", "id.umaxica.com")],
      [Email::Org::OtpMailer, "mail-org-public-id", "org-token", ENV.fetch("ID_STAFF_URL", "id.umaxica.org")],
    ].each do |mailer, public_id, token, host|
      mail = mailer.with(
        encrypted_hotp_token: encrypted_otp("123456"),
        email_address: "target@example.com",
        public_id: public_id,
        verification_token: token,
      ).create

      assert_match host, mail.html_part.body.decoded
      assert_match public_id, mail.html_part.body.decoded
      assert_match token, mail.html_part.body.decoded
      assert_match host, mail.text_part.body.decoded
      assert_match public_id, mail.text_part.body.decoded
      assert_match token, mail.text_part.body.decoded
    end
  end

  test "otp mailer enqueue arguments do not include plaintext otp" do
    clear_enqueued_jobs

    Email::App::OtpMailer.with(
      encrypted_hotp_token: encrypted_otp("112233"),
      email_address: "target@example.com",
    ).create.deliver_later

    job_payload = enqueued_jobs.last[:args].inspect

    assert_includes job_payload, "encrypted_hotp_token"
    assert_no_match(/"hotp_token"\s*=>/, job_payload)
    assert_not_includes job_payload, "112233"
  end

  test "alert mailers send a generic alert payload per surface" do
    [
      [Email::App::AlertMailer, "alert@umaxica.app"],
      [Email::Com::AlertMailer, "alert@umaxica.com"],
      [Email::Org::AlertMailer, "alert@umaxica.org"],
    ].each do |mailer, sender|
      mail = mailer.with(email_address: "target@example.com", title: "Alert title", body: "Alert body").notice

      assert_equal "Alert title", mail.subject
      assert_equal ["target@example.com"], mail.to
      assert_equal [sender], mail.from
      assert_match "Alert body", mail.text_part.body.decoded
    end
  end

  test "promotional mailers send from promotional addresses per surface" do
    [
      [Email::App::PromotionalMailer, "promotion@umaxica.app"],
      [Email::Com::PromotionalMailer, "promotion@umaxica.com"],
      [Email::Org::PromotionalMailer, "promotion@umaxica.org"],
    ].each do |mailer, sender|
      mail = mailer.with(
        email_address: "target@example.com",
        title: "Promotion title",
        body: "Promotion body",
        cta_url: "https://example.com/campaign",
      ).notice

      assert_equal "Promotion title", mail.subject
      assert_equal ["target@example.com"], mail.to
      assert_equal [sender], mail.from
      assert_match "Promotion body", mail.text_part.body.decoded
      assert_match "https://example.com/campaign", mail.text_part.body.decoded
    end
  end

  test "promotional mailers omit unsafe cta urls" do
    [
      Email::App::PromotionalMailer,
      Email::Com::PromotionalMailer,
      Email::Org::PromotionalMailer,
    ].each do |mailer|
      mail = mailer.with(
        email_address: "target@example.com",
        title: "Promotion title",
        body: "Promotion body",
        cta_url: "javascript:alert(1)",
      ).notice

      assert_match "Promotion body", mail.text_part.body.decoded
      assert_not_includes mail.text_part.body.decoded, "javascript:alert"
      assert_not_includes mail.html_part.body.decoded, "javascript:alert"
    end
  end

  test "promotional mailers omit cta urls with credentials" do
    [
      Email::App::PromotionalMailer,
      Email::Com::PromotionalMailer,
      Email::Org::PromotionalMailer,
    ].each do |mailer|
      mail = mailer.with(
        email_address: "target@example.com",
        title: "Promotion title",
        body: "Promotion body",
        cta_url: "https://user:pass@example.com/campaign",
      ).notice

      assert_not_includes mail.text_part.body.decoded, "user:pass"
      assert_not_includes mail.html_part.body.decoded, "user:pass"
    end
  end

  test "promotional mailers can set unsubscribe headers per surface" do
    [
      [Email::App::PromotionalMailer, ClientEmail.new(public_id: "app-email-public-id"), "promotion@umaxica.app"],
      [Email::Com::PromotionalMailer, VisitorEmail.new(public_id: "com-email-public-id"), "promotion@umaxica.com"],
      [Email::Org::PromotionalMailer, OperatorEmail.new(public_id: "org-email-public-id"), "promotion@umaxica.org"],
    ].each do |mailer, email_record, sender|
      mail = mailer.with(
        email_address: "target@example.com",
        title: "Promotion title",
        body: "Promotion body",
        cta_url: "https://example.com/campaign",
        email_record: email_record,
      ).notice

      assert_equal "Promotion title", mail.subject
      assert_equal [sender], mail.from
      assert_match "List-Unsubscribe", mail.header.to_s
    end
  end

  private

  def encrypted_otp(code)
    OutboundSensitivePayload.encrypt_email_otp(code)
  end
end

# rubocop:enable Rails/I18nLocaleTexts
