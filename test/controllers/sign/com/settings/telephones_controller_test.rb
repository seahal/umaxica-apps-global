# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Settings::TelephonesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include AuthHelpers
  include SignRouteAliasHelper

  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    host! @host
    @visitor = create_verified_visitor_with_email(email_address: "telephones-#{SecureRandom.hex(4)}@example.com")
    @token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_telephone")
    set_access_cookie(jwt_access_token_for(@visitor, host: @host, session_public_id: @token.public_id))
  end

  def request_headers
    as_visitor_headers(@visitor, host: @host, session_public_id: @token.public_id)
  end

  test "sign settings telephones index redirects to acme authority" do
    get sign_com_settings_telephones_url(ri: "jp")

    assert_redirected_to new_sign_com_settings_telephones_registration_url(ri: "jp")
  end

  test "legacy sign settings telephone edit remains on sign authority" do
    telephone = VisitorTelephone.create!(
      number: "+10000000031",
      visitor: @visitor,
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    get edit_sign_com_settings_telephone_url(telephone.public_id, ri: "jp"), headers: request_headers

    if response.redirect?
      assert_match %r{\Ahttp://#{Regexp.escape(@host)}/verification\?}, response.location
      assert_includes response.location, "scope=settings_telephone"
    else
      assert_response :success
      assert_select(
        "form[action=?]",
        acme_com_settings_telephone_url(telephone.public_id, ri: "jp", host: @acme_host),
        count: 1,
      )
    end
  end

  test "sign settings telephone destroy redirects without local account mutation" do
    telephone = VisitorTelephone.create!(
      number: "+10000000030",
      visitor: @visitor,
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    assert_difference("VisitorTelephone.count", -1) do
      delete sign_com_settings_telephone_url(telephone.public_id, ri: "jp")
    end

    assert_redirected_to sign_com_settings_telephones_url(ri: "jp")
  end

  test "legacy sign settings telephone new redirects to registration ceremony when setup is incomplete" do
    get new_sign_com_settings_telephone_url(ri: "jp"), headers: request_headers

    assert_redirected_to new_sign_com_settings_telephones_registration_url(ri: "jp")
  end

  test "legacy sign settings telephone create redirects without local mutation when setup is incomplete" do
    assert_no_enqueued_jobs only: Outbound::SmsDeliveryJob do
      assert_no_difference("VisitorTelephone.count") do
        post sign_com_settings_telephones_url(ri: "jp"),
             params: { user_telephone: { raw_number: "+10000000028" } },
             headers: request_headers
      end
    end

    assert_redirected_to new_sign_com_settings_telephones_registration_url(ri: "jp")
  end
end
