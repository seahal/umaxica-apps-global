# typed: false
# frozen_string_literal: true

require "test_helper"

class VerificationI18nTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_statuses

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    host! @host
    @user = users(:one)
    @token = UserToken.create!(
      user: @user,
      user_token_status_id: UserTokenStatus::NOTHING,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      public_id: "verify_i18n_#{SecureRandom.hex(4)}",
      refresh_expires_at: 1.day.from_now,
    )
    @headers = browser_headers.merge(
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    ).freeze

    UserEmail.create!(
      user: @user,
      address: "verify-i18n-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )
  end

  test "verification view displays translated strings in Japanese" do
    UserReauthSession.delete_all

    get sign_app_verification_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "main h1", text: I18n.t("sign.app.verification.index.title", locale: :ja)
    assert_select "h2", text: I18n.t("sign.app.verification.new.title", locale: :ja)
  end

  test "verification view displays translated strings in English" do
    UserReauthSession.delete_all

    get sign_app_verification_url(ri: "us", lx: "en"), headers: @headers

    assert_response :success
    assert_select "main h1", text: I18n.t("sign.app.verification.index.title", locale: :en)
    assert_select "h2", text: I18n.t("sign.app.verification.new.title", locale: :en)
  end
end
