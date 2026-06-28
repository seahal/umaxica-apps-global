# typed: false
# frozen_string_literal: true

require "test_helper"

class Core::App::SignOutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds

  setup do
    host! ENV.fetch("CORE_SERVICE_URL")
  end

  test "get sign out renders confirmation without mutation" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get edit_core_app_sign_out_url(ri: "jp"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success
    assert_select "form[action*=?][method=?]", core_app_sign_out_path, "post"
    assert_predicate token.reload, :currently_usable?
  end

  test "post sign out redirects to acme oidc logout with completion state" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post core_app_sign_out_url(ri: "jp"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success
    location = URI.parse(handoff_form["action"])
    Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("ACME_SERVICE_URL"), location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate handoff_input_value("logout_challenge"), :present?
    assert_equal "jp", handoff_input_value("ri")
    assert_predicate token.reload, :revoked?
  end

  test "post sign out accepts us region" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post core_app_sign_out_url(ri: "us"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success
    location = URI.parse(handoff_form["action"])
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("ACME_SERVICE_URL"), location.host
    assert_equal "/oidc/logout", location.path
    assert_equal "us", handoff_input_value("ri")
    assert_includes query.fetch("post_logout_redirect_uri"), "ri=us"
    assert_predicate handoff_input_value("logout_challenge"), :present?
    assert_predicate token.reload, :revoked?
  end

  test "post sign out canonicalizes unsupported region to default" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post core_app_sign_out_url(ri: "xx"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success
    location = URI.parse(handoff_form["action"])
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal "/oidc/logout", location.path
    assert_equal RequestContextContract.default_region, handoff_input_value("ri")
    assert_includes query.fetch("post_logout_redirect_uri"), "ri=#{RequestContextContract.default_region}"
    assert_predicate token.reload, :revoked?
  end

  test "transaction issuance failure does not render success completion" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!
    rejected = AcmeLogoutTransactionCoordinator::Result.new(
      transaction: nil,
      status: :rejected,
      error: "invalid_request",
      error_description: "completion destination is not allowlisted",
    )

    AcmeLogoutTransactionCoordinator.stub(:issue!, rejected) do
      post core_app_sign_out_url(ri: "us"), headers: {
        "X-TEST-CURRENT-USER" => user.id.to_s,
        "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
      }
    end

    assert_response :unprocessable_content
    assert_predicate token.reload, :currently_usable?
    assert_not_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
    assert_includes response.body, I18n.t("sign.shared.sign_out.unavailable_title")
    assert_select "form[action*=?][method=?]", core_app_sign_out_path, "post"
  end

  test "post sign out without region uses the default completion region" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post core_app_sign_out_url, headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success
    location = URI.parse(handoff_form["action"])
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("ACME_SERVICE_URL"), location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate handoff_input_value("logout_challenge"), :present?
    assert_equal RequestContextContract.default_region, handoff_input_value("ri")
    assert_includes query.fetch("post_logout_redirect_uri"), "ri=#{RequestContextContract.default_region}"
  end

  test "post sign out relay advances to sign coordination hop" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post core_app_sign_out_url(ri: "jp"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    challenge = handoff_input_value("logout_challenge")

    post acme_app_oidc_logout_url(
      host: ENV.fetch("ACME_SERVICE_URL"), ri: "jp",
      logout_challenge: challenge,
    ), headers: {
      "Host" => ENV.fetch("ACME_SERVICE_URL"),
      "Origin" => "https://#{ENV.fetch("CORE_SERVICE_URL")}",
      "Sec-Fetch-Site" => "same-site",
    }

    assert_response :success
    location = URI.parse(handoff_form["action"])

    assert_equal ENV.fetch("PRIVATE_SIGN_SERVICE_URL"), location.host
    assert_equal "/sign/out", location.path
    assert_equal challenge, handoff_input_value("logout_challenge")
    assert_equal "jp", handoff_input_value("ri")
  end

  private

  def handoff_form
    assert_select "form#sign-out-handoff-form[method=post][data-turbo=false]", 1
    css_select("form#sign-out-handoff-form").first
  end

  def handoff_input_value(name)
    css_select(%(form#sign-out-handoff-form input[name="#{name}"])).first&.[]("value")
  end
end
