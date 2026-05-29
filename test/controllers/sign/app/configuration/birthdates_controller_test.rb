# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign::App::Configuration
  class BirthdatesControllerTest < ActionDispatch::IntegrationTest
    fixtures :clients, :client_statuses

    setup do
      @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      host! @host
      @user = clients(:one)
      @user.update!(birthdate: "2000-02-03")
      @headers = as_user_headers(@user, host: @host)
      @token = ClientToken.find_by!(public_id: @headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
      mark_token_step_up_satisfied_for_test(@token, scope: "configuration_birthdate")
    end

    test "shows birthdate to signed in client" do
      get sign_app_configuration_birthdate_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_select "[data-birthdate]", text: "2000-02-03"
      assert_select "a[href=?]", sign_app_configuration_path(ri: "jp")
      assert_select "input[name*='birthdate']", count: 0
    end

    test "shows unset state" do
      @user.update!(birthdate: nil)

      get sign_app_configuration_birthdate_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_includes response.body, I18n.t("sign.app.configuration.birthdate.show.not_set")
    end

    test "requires step-up when session freshness is stale" do
      @token.update!(last_step_up_at: nil, last_step_up_scope: nil)

      get sign_app_configuration_birthdate_url(ri: "jp"), headers: @headers

      assert_response :redirect
      assert_match(%r{/verification}, response.location)
    end

    test "rejects generic verification step-up scope" do
      @token.update!(last_step_up_at: Time.current, last_step_up_scope: "verification")

      get sign_app_configuration_birthdate_url(ri: "jp"), headers: @headers

      assert_response :redirect
      assert_match(%r{/verification}, response.location)
      assert_not_includes response.body, "2000-02-03"
    end

    test "rejects unrelated step-up scope" do
      @token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_secret")

      get sign_app_configuration_birthdate_url(ri: "jp"), headers: @headers

      assert_response :redirect
      assert_match(%r{/verification}, response.location)
      assert_not_includes response.body, "2000-02-03"
    end

    test "redirects when not signed in" do
      get sign_app_configuration_birthdate_url(ri: "jp"), headers: { "Host" => @host }

      assert_response :redirect
      uri = URI.parse(response.location)
      query = Rack::Utils.parse_nested_query(uri.query)

      assert_equal "jump.umaxica.net", uri.host
      assert_match %r{\Ahttps://id\.umaxica\.app/sign/in/new\?ri=jp\z}, jump_rt_url_from_location(response.location)
    end

    test "does not route mutation or edit actions" do
      assert_raises(NoMethodError) do
        edit_sign_app_configuration_birthdate_url(ri: "jp")
      end

      patch sign_app_configuration_birthdate_url(ri: "jp"), headers: @headers, params: {
        client: { birthdate: "2001-02-03" },
      }

      assert_response :not_found
      assert_equal "2000-02-03", @user.reload.birthdate
    end
  end
end
