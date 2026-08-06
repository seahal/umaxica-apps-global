# typed: false
# frozen_string_literal: true

require "test_helper"

# The social ceremony result is posted from the Auth host to the Base host by an
# auto-submitting form. Forgery protection is disabled for most of the suite, so
# this test turns it on to cover the cross-host origin the browser actually sends.
class SocialCompletionCrossHostCsrfTest < ActionDispatch::IntegrationTest
  setup do
    @original_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @original_forgery_protection
  end

  test "completion accepts the auth host origin and rejects on the ceremony result instead" do
    post base_app_social_authentication_completion_path(id: "google"),
         params: { social_ceremony_result: "not-a-valid-result-token", ri: "jp" },
         headers: {
           "Host" => @base_host,
           "Origin" => "https://#{@auth_host}",
           "Sec-Fetch-Site" => "same-site",
         }

    # The request reached the action: it fails on the unverifiable ceremony
    # result, not on forgery protection.
    assert_response :unprocessable_content
    assert_equal "text/plain", response.media_type
    assert_equal I18n.t("sign.app.social.sessions.create.failure"), response.body
  end

  test "completion accepts a same-site null origin instead of raising a cross-origin error" do
    post base_app_social_authentication_completion_path(id: "google"),
         params: { social_ceremony_result: "not-a-valid-result-token", ri: "jp" },
         headers: {
           "Host" => @base_host,
           "Origin" => "null",
           "Sec-Fetch-Site" => "same-site",
         }

    assert_response :unprocessable_content
    assert_equal "text/plain", response.media_type
    assert_equal I18n.t("sign.app.social.sessions.create.failure"), response.body
  end

  test "completion rejects a null origin that is not same-site" do
    post base_app_social_authentication_completion_path(id: "google"),
         params: { social_ceremony_result: "not-a-valid-result-token", ri: "jp" },
         headers: {
           "Host" => @base_host,
           "Origin" => "null",
           "Sec-Fetch-Site" => "cross-site",
         }

    assert_response :unprocessable_content
    assert_not_equal "text/plain", response.media_type
  end

  test "completion still rejects an untrusted third-party origin" do
    post base_app_social_authentication_completion_path(id: "google"),
         params: { social_ceremony_result: "not-a-valid-result-token", ri: "jp" },
         headers: {
           "Host" => @base_host,
           "Origin" => "https://attacker.example.com",
           "Sec-Fetch-Site" => "cross-site",
         }

    assert_response :unprocessable_content
    assert_not_equal "text/plain", response.media_type
  end
end
