# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgVerificationI18nTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    host! @host
    OperatorRecord.connected_to(role: :writing) do
      OperatorIdentityStatus.insert_missing_fixed_ids!(
        [OperatorIdentityStatus::ACTIVE,
         OperatorIdentityStatus::NOTHING, OperatorIdentityStatus::RESERVED,],
      )
    end

    @staff = Operator.create!(status_id: OperatorIdentityStatus::NOTHING, public_id: Operator.generate_public_id)
    @token = OperatorToken.create!(
      staff: @staff,
      staff_token_status_id: OperatorTokenStatus::NOTHING,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      public_id: "ov_i18n_#{SecureRandom.hex(4)}",
      lapses_at: 1.day.from_now,
    )
    @headers = browser_headers.merge(
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    ).freeze

    OperatorPasskey.create!(
      staff: @staff,
      name: "verify i18n passkey",
      webauthn_id: "org-verify-i18n-#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
  end

  test "verification view displays translated strings in Japanese" do
    OperatorReauthSession.delete_all

    get sign_org_verification_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "main h1", text: I18n.t("sign.org.verification.index.title", locale: :ja)
    assert_select "h2", text: I18n.t("sign.org.verification.new.title", locale: :ja)
  end

  test "verification view displays translated strings in English" do
    OperatorReauthSession.delete_all

    get sign_org_verification_url(ri: "us", lx: "en"), headers: @headers

    assert_response :success
    assert_select "main h1", text: I18n.t("sign.org.verification.index.title", locale: :en)
    assert_select "h2", text: I18n.t("sign.org.verification.new.title", locale: :en)
  end
end
