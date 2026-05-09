# typed: false
# frozen_string_literal: true

require "test_helper"

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
end
