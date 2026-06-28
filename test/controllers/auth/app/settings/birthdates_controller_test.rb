# typed: false
# frozen_string_literal: true

require "test_helper"

module Auth::App::Settings
  class BirthdatesControllerTest < ActionDispatch::IntegrationTest
    fixtures :clients, :client_statuses

    setup do
      @host = ENV.fetch("AUTH_SERVICE_URL")
      host! @host
      @user = clients(:one)
      @user.update!(birthdate: "2000-02-03")
      @headers = as_user_headers(@user, host: @host)
      @token = ClientToken.find_by!(public_id: @headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
      mark_token_step_up_satisfied_for_test(@token, scope: "settings_birthdate")
    end

    test "shows birthdate to signed in client" do
      get auth_app_settings_birthdate_url(ri: "jp"), headers: @headers

      assert_redirected_to base_app_identity_birthdate_path(ri: "jp")
    end

    test "shows unset state" do
      @user.update!(birthdate: nil)

      get auth_app_settings_birthdate_url(ri: "jp"), headers: @headers

      assert_redirected_to base_app_identity_birthdate_path(ri: "jp")
    end

    test "requires step-up when session freshness is stale" do
      @token.update!(last_step_up_at: nil, last_step_up_scope: nil)

      get auth_app_settings_birthdate_url(ri: "jp"), headers: @headers

      assert_redirected_to base_app_identity_birthdate_path(ri: "jp")
    end

    test "rejects generic verification step-up scope" do
      @token.update!(last_step_up_at: Time.current, last_step_up_scope: "verification")

      get auth_app_settings_birthdate_url(ri: "jp"), headers: @headers

      assert_redirected_to base_app_identity_birthdate_path(ri: "jp")
    end

    test "rejects unrelated step-up scope" do
      @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_secret_credential")

      get auth_app_settings_birthdate_url(ri: "jp"), headers: @headers

      assert_redirected_to base_app_identity_birthdate_path(ri: "jp")
    end

    test "redirects when not signed in" do
      get auth_app_settings_birthdate_url(ri: "jp"), headers: { "Host" => @host }

      assert_redirected_to base_app_identity_birthdate_path(ri: "jp")
    end

    test "does not route mutation or edit actions" do
      assert_raises(NoMethodError) do
        edit_auth_app_settings_birthdate_url(ri: "jp")
      end

      patch auth_app_settings_birthdate_url(ri: "jp"), headers: @headers, params: {
        client: { birthdate: "2001-02-03" },
      }

      assert_response :not_found
      assert_equal "2000-02-03", @user.reload.birthdate
    end
  end
end
