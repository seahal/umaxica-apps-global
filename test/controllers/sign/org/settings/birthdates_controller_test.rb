# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign::Org::Settings
  class BirthdatesControllerTest < ActionDispatch::IntegrationTest
    fixtures :operators, :operator_statuses

    setup do
      @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
      host! @host
      @staff = operators(:one)
      @staff.update!(birthdate: "1990-12-31")
      @headers = as_staff_headers(@staff, host: @host)
      @token = OperatorToken.find_by!(public_id: @headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
      satisfy_staff_verification(@token)
      mark_token_step_up_satisfied_for_test(@token, scope: "settings_birthdate")
    end

    test "shows birthdate to signed in operator" do
      get sign_org_settings_birthdate_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_select "[data-birthdate]", text: "1990-12-31"
      assert_select "a[href=?]", sign_org_settings_path(ri: "jp")
      assert_select "input[name*='birthdate']", count: 0
    end

    test "shows unset state" do
      @staff.update!(birthdate: nil)

      get sign_org_settings_birthdate_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_includes response.body, I18n.t("sign.org.settings.birthdate.show.not_set")
    end

    test "requires step-up when session freshness is stale" do
      @token.update!(last_step_up_at: nil, last_step_up_scope: nil)

      get sign_org_settings_birthdate_url(ri: "jp"), headers: @headers

      assert_response :redirect
      assert_match(%r{/verification}, response.location)
    end

    test "rejects generic verification step-up scope" do
      @token.update!(last_step_up_at: Time.current, last_step_up_scope: "verification")

      get sign_org_settings_birthdate_url(ri: "jp"), headers: @headers

      assert_response :redirect
      assert_match(%r{/verification}, response.location)
      assert_not_includes response.body, "1990-12-31"
    end

    test "rejects unrelated step-up scope" do
      @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_secret_credential")

      get sign_org_settings_birthdate_url(ri: "jp"), headers: @headers

      assert_response :redirect
      assert_match(%r{/verification}, response.location)
      assert_not_includes response.body, "1990-12-31"
    end

    test "redirects when not signed in" do
      get sign_org_settings_birthdate_url(ri: "jp")

      assert_response :redirect
      assert_oidc_authorize_redirect(
        response.location,
        host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
        client_id: "sign-rp",
      )
    end

    test "does not route mutation or edit actions" do
      assert_raises(NoMethodError) do
        edit_sign_org_settings_birthdate_url(ri: "jp")
      end

      patch sign_org_settings_birthdate_url(ri: "jp"), headers: @headers, params: {
        operator: { birthdate: "1991-01-01" },
      }

      assert_response :not_found
      assert_equal "1990-12-31", @staff.reload.birthdate
    end
  end
end
