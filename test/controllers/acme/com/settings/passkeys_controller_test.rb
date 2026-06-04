# typed: false
# frozen_string_literal: true

require "test_helper"
require "action_policy/test_helper"

class Acme::Com::Settings::PasskeysControllerTest < ActionDispatch::IntegrationTest
  include ActionPolicy::TestHelper

  setup do
    @host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    host! @host

    @visitor = create_verified_visitor_with_email(email_address: "acme-com-passkey-owner@example.com")
    @headers = as_visitor_headers(@visitor, host: @host)
    @token = VisitorToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    satisfy_visitor_verification(@token)
    mark_token_step_up_satisfied_for_test(@token, scope: "settings_passkey")

    @passkey = create_passkey(@visitor, "Owner Passkey")
  end

  test "show resolves passkey from public id params" do
    get acme_com_settings_passkey_url(@passkey.public_id, ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_includes response.body, "Owner Passkey"
  end

  test "index lists only the current visitor passkeys" do
    other_visitor = create_verified_visitor_with_email(email_address: "acme-com-passkey-other@example.com")
    create_passkey(other_visitor, "Other Visitor Passkey")

    get acme_com_settings_passkeys_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_includes response.body, "Owner Passkey"
    assert_not_includes response.body, "Other Visitor Passkey"
  end

  test "index applies VisitorPasskeyPolicy relation scope" do
    assert_have_authorized_scope(type: :active_record_relation, with: VisitorPasskeyPolicy) do
      get acme_com_settings_passkeys_url(ri: "jp", host: @host), headers: @headers
    end

    assert_response :success
  end

  private

  def create_passkey(visitor, description)
    VisitorPasskey.create!(
      visitor: visitor,
      webauthn_id: SecureRandom.urlsafe_base64(16),
      public_key: "public_key_#{SecureRandom.hex(4)}",
      sign_count: 0,
      description: description,
      status_id: VisitorPasskeyStatus::ACTIVE,
    )
  end
end
