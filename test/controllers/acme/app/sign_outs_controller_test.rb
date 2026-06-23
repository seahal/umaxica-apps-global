# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds

  setup do
    @host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    host! @host
  end

  test "new sign out redirects to confirmation without mutation" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get new_acme_app_sign_out_url(host: @host, ri: "us"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :see_other
    assert_equal edit_acme_app_sign_out_url(host: @host, ri: "us"), response.location
    assert_predicate token.reload, :currently_usable?
  end

  test "new sign out preserves logout challenge on redirect" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    challenge = "logout_challenge_123"

    get new_acme_app_sign_out_url(host: @host, ri: "us", logout_challenge: challenge), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :see_other
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal "/sign/out/edit", uri.path
    assert_equal "us", query["ri"]
    assert_equal challenge, query["logout_challenge"]
  end

  test "edit sign out renders confirmation without mutation" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get edit_acme_app_sign_out_url(host: @host, ri: "us"), headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success
    assert_select "p", text: I18n.t("sign.shared.sign_out.confirm_description")
    assert_select "form[action*=?][method=?]", acme_app_sign_out_path, "post"
    assert_predicate token.reload, :currently_usable?
  end

  test "edit sign out rejects an invalid coordination challenge without mutation" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get edit_acme_app_sign_out_url(host: @host, ri: "us", logout_challenge: "invalid-challenge"),
        headers: {
          "X-TEST-CURRENT-USER" => user.id.to_s,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :unprocessable_content
    assert_select "h1", text: I18n.t("sign.shared.sign_out.unavailable_title")
    assert_predicate token.reload, :currently_usable?
  end

  test "post sign out starts the coordinated acme -> sign -> acme circuit" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post acme_app_sign_out_url(host: @host, ri: "jp"),
         headers: browser_headers.merge(
           "Host" => @host,
           "X-TEST-CURRENT-USER" => user.id.to_s,
           "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
         )

    assert_response :success
    assert_equal SignOutNotice::SIGN_OUT_HANDOFF_REFERRER_POLICY, response.headers["Referrer-Policy"]
    assert_select %(meta[name="referrer"][content="no-referrer"]), 0
    assert_equal 1, css_select("script").count { |node| node.text.include?("requestSubmit") }
    assert_predicate token.reload, :revoked?

    sign_handoff = handoff_form
    sign_challenge = handoff_input_value("logout_challenge")

    assert_equal sign_app_sign_out_url(host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"), protocol: "https"),
                 sign_handoff["action"]
    assert_predicate sign_challenge, :present?

    post sign_app_sign_out_url(
      host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
      ri: "jp",
      logout_challenge: sign_challenge,
    ), headers: browser_headers.merge(
      "Host" => ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
      "Origin" => "https://#{@host}",
      "Sec-Fetch-Site" => "same-site",
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )

    assert_response :see_other
    assert_equal complete_acme_app_sign_out_url(ri: "jp", host: @host, protocol: "https"),
                 jump_rt_url_from_location(response.location)

    get jump_rt_url_from_location(response.location)

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end

  test "post sign out revokes the current session when only refresh cookie is present" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post acme_app_sign_out_url(host: @host, ri: "jp"), headers: browser_headers.merge("Host" => @host)

    assert_response :success
    assert_predicate token.reload, :revoked?
  end

  test "post sign out without a resolved session still begins the circuit" do
    post acme_app_sign_out_url(host: @host, ri: "jp"), headers: browser_headers.merge("Host" => @host)

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end

  private

  def assert_sign_out_handoff_markup(action_path:)
    assert_select "form#sign-out-handoff-form[method=post][data-turbo=false]", 1
    form = css_select("form#sign-out-handoff-form").first

    assert_equal action_path, form["action"]
    assert_equal SignOutNotice::SIGN_OUT_HANDOFF_REFERRER_POLICY, response.headers["Referrer-Policy"]
    assert_select %(meta[name="referrer"][content="no-referrer"]), 0
    assert_select "form#sign-out-handoff-form input[name=authenticity_token]", 0
    assert_select "form#sign-out-handoff-form noscript input[type=submit][value=?]",
                  I18n.t("sign.shared.sign_out.handoff_button"),
                  0
    assert_select "noscript button[form=sign-out-handoff-form][type=submit]", 1
    scripts =
      css_select("script").select { |node|
        node.text.include?('document.getElementById("sign-out-handoff-form")')
      }
    script = scripts.first

    assert script, "missing sign-out handoff auto-submit script"
    assert_equal 1, scripts.size
    assert_predicate script["nonce"], :present?
    assert_includes script.text, "requestSubmit"
  end

  def handoff_form
    assert_select "form#sign-out-handoff-form[method=post][data-turbo=false]", 1
    css_select("form#sign-out-handoff-form").first
  end

  def handoff_input_value(name)
    css_select(%(form#sign-out-handoff-form input[name="#{name}"])).first&.[]("value")
  end
end
