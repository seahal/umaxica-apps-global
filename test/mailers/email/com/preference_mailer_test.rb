# typed: false
# frozen_string_literal: true

require "test_helper"

module Email::Com
  class PreferenceMailerTest < ActionMailer::TestCase
    test "PreferenceMailer has update_request method" do
      assert_respond_to PreferenceMailer, :update_request
    end

    test "PreferenceMailer inherits from ApplicationMailer" do
      assert_kind_of Class, PreferenceMailer
      assert_operator PreferenceMailer, :<, ApplicationMailer
    end

    def build_mail(address:, edit_url:)
      preference_request = Struct.new(:address).new(address)
      PreferenceMailer.with(preference_request: preference_request, edit_url: edit_url).update_request
    end

    test "update_request sends preference request email with expected subject and recipient" do
      mail = build_mail(address: "company@example.com", edit_url: "https://example.com/preferences/edit")

      assert_equal ["company@example.com"], mail.to
      assert_equal I18n.t("email.com.preference_mailer.update_request.subject"), mail.subject
      assert_match "https://example.com/preferences/edit", mail.text_part.body.decoded
    end

    test "update_request builds a multipart email" do
      mail = build_mail(address: "company@example.net", edit_url: "https://example.net/update_preferences")

      assert_predicate mail, :multipart?
    end

    test "text part contains localized intro and edit link" do
      edit_url = "https://example.org/preferences/edit"
      mail = build_mail(address: "company@example.org", edit_url: edit_url)

      assert_not_nil mail.text_part
      text_body = mail.text_part.body.decoded

      assert_match I18n.t("email.com.preference_mailer.update_request.intro"), text_body
      assert_match edit_url, text_body
    end

    test "html part contains localized CTA and edit link" do
      edit_url = "https://example.org/preferences/modify"
      mail = build_mail(address: "company@example.org", edit_url: edit_url)

      assert_not_nil mail.html_part
      html_body = mail.html_part.body.decoded

      assert_match I18n.t("email.com.preference_mailer.update_request.cta"), html_body
      assert_match edit_url, html_body
    end
  end
end
