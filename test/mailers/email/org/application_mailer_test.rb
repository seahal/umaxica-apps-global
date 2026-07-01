# typed: false
# frozen_string_literal: true

# rubocop:disable Rails/I18nLocaleTexts

require "test_helper"
# require "helpers/global_test_support"

class Email::Org::ApplicationMailerTest < ActionMailer::TestCase
  test "applies default from address" do
    expected_from = "from@umaxica.org"

    assert_equal expected_from, Email::Org::ApplicationMailer.default[:from]

    mailer =
      Class.new(Email::Org::ApplicationMailer) do
        define_method(:sample) do
          mail(
            to: "org-user@example.com",
            subject: I18n.t("test.email.org.application_mailer.subject"),
          ) do |format|
            format.text { render plain: "hello" }
          end
        end
      end

    I18n.backend.store_translations(
      :en,
      { test: { email: { org: { application_mailer: { subject: "Org Sample" } } } } },
    )
    email = mailer.new.sample

    assert_equal [expected_from], email.from
    assert_equal ["org-user@example.com"], email.to
    assert_equal I18n.t("test.email.org.application_mailer.subject"), email.subject
    assert_equal "hello", email.body.encoded
  end

  test "uses organization mailer layout" do
    assert_equal "mailer/org/mailer", Email::Org::ApplicationMailer._layout
  end

  test "sets promotional unsubscribe headers when requested" do
    operator = operators(:one)
    email_record = OperatorEmail.create!(
      staff: operator,
      address: "mailer-operator-#{SecureRandom.hex(4)}@example.com",
      staff_identity_email_status_id: OperatorEmailStatus::VERIFIED,
      confirm_policy: "1",
    )

    mailer =
      Class.new(Email::Org::ApplicationMailer) do
        define_method(:sample) do
          set_promotional_unsubscribe_headers(params.fetch(:email_record))
          mail(to: "operator@example.com", subject: "Operator Sample") do |format|
            format.text { render plain: "hello" }
          end
        end
      end

    email = mailer.with(email_record: email_record).sample
    expected_url = Rails.application.routes.url_helpers.base_org_preference_email_url(
      email_record,
      token: email_record.promotional_unsubscribe_token,
      host: Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host,
    )

    assert_equal "<#{expected_url}>", email["List-Unsubscribe"].value
    assert_equal "List-Unsubscribe=One-Click", email["List-Unsubscribe-Post"].value
  end
end

# rubocop:enable Rails/I18nLocaleTexts
