# typed: false
# frozen_string_literal: true

require "test_helper"

module Auth::Com::Settings
  class BirthdatesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
      @visitor = create_verified_visitor_with_email(email_address: "birthdate-#{SecureRandom.hex(4)}@example.com")
      VisitorTelephone.create!(
        visitor: @visitor,
        raw_number: "+81902222#{SecureRandom.random_number(10_000).to_s.rjust(4, "0")}",
        visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
      )
      @visitor.reload
      @visitor.update!(birthdate: "2000-02-30")
      @headers = as_visitor_headers(@visitor, host: @host)
      @token = VisitorToken.find_by!(public_id: @headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
      satisfy_visitor_verification(@token)
      mark_token_step_up_satisfied_for_test(@token, scope: "settings_birthdate")
    end

    test "shows birthdate to signed in visitor" do
      get auth_com_settings_birthdate_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_select "[data-birthdate]", text: "2000-02-30"
      assert_select "a[href=?]", auth_com_settings_path(ri: "jp")
      assert_select "input[name*='birthdate']", count: 0
    end

    test "shows unset state" do
      @visitor.update!(birthdate: nil)

      get auth_com_settings_birthdate_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_includes response.body, I18n.t("sign.com.settings.birthdate.show.not_set")
    end

    test "requires step-up when session freshness is stale" do
      @token.update!(last_step_up_at: nil, last_step_up_scope: nil)

      get auth_com_settings_birthdate_url(ri: "jp"), headers: @headers

      assert_response :redirect
      assert_match(%r{/verification}, response.location)
    end

    test "rejects generic verification step-up scope" do
      @token.update!(last_step_up_at: Time.current, last_step_up_scope: "verification")

      get auth_com_settings_birthdate_url(ri: "jp"), headers: @headers

      assert_response :redirect
      assert_match(%r{/verification}, response.location)
      assert_not_includes response.body, "2000-02-30"
    end

    test "rejects unrelated step-up scope" do
      @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_secret_credential")

      get auth_com_settings_birthdate_url(ri: "jp"), headers: @headers

      assert_response :redirect
      assert_match(%r{/verification}, response.location)
      assert_not_includes response.body, "2000-02-30"
    end

    test "redirects when not signed in" do
      get auth_com_settings_birthdate_url(ri: "jp"), headers: { "Host" => @host }

      assert_response :redirect
      assert_oidc_authorize_redirect(
        response.location,
        host: ENV.fetch("PRIVATE_ACME_CORPORATE_URL", "www.com.localhost"),
        client_id: "sign-rp",
      )
    end

    test "does not route mutation or edit actions" do
      assert_raises(NoMethodError) do
        edit_auth_com_settings_birthdate_url(ri: "jp")
      end

      patch auth_com_settings_birthdate_url(ri: "jp"), headers: @headers, params: {
        visitor: { birthdate: "2001-02-03" },
      }

      assert_response :not_found
      assert_equal "2000-02-30", @visitor.reload.birthdate
    end
  end
end
