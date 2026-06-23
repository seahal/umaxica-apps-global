# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_statuses, :client_token_kinds

  test "get sign out renders confirmation without mutation" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get edit_sign_app_sign_out_url(ri: "jp", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
        headers: as_user_headers(
          user, host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
                session_public_id: token.public_id,
        )

    assert_response :success
    assert_predicate token.reload, :currently_usable?
  end

  test "post sign out redirects to acme oidc logout with logout challenge" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post sign_app_sign_out_url(ri: "jp", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
         headers: browser_headers.merge(
           "Host" => ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
           "X-TEST-CURRENT-USER" => user.id.to_s,
           "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
         )

    assert_response :success
    location = URI.parse(handoff_form["action"])

    assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate handoff_input_value("logout_challenge"), :present?
    assert_equal "jp", handoff_input_value("ri")
    assert_predicate token.reload, :revoked?
  end

  test "post sign out does not require Turnstile verification" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    JitSecurityTurnstileVerifier.stub(:verify, ->(**) { flunk("sign out must not verify Turnstile") }) do
      post sign_app_sign_out_url(ri: "jp", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
           headers: browser_headers.merge(
             "Host" => ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
             "X-TEST-CURRENT-USER" => user.id.to_s,
             "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
           )
    end

    assert_response :success
    assert_predicate token.reload, :revoked?
  end

  test "post sign out accepts us region without rendering completion" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post sign_app_sign_out_url(ri: "us", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
         headers: browser_headers.merge(
           "Host" => ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
           "X-TEST-CURRENT-USER" => user.id.to_s,
           "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
         )

    assert_response :success
    location = URI.parse(handoff_form["action"])
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_equal "us", handoff_input_value("ri")
    assert_includes query.fetch("post_logout_redirect_uri"), "ri=us"
    assert_predicate handoff_input_value("logout_challenge"), :present?
    assert_predicate token.reload, :revoked?
    assert_not_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
  end

  test "post sign out canonicalizes region input through request contract" do
    {
      "JP" => "jp",
      "US" => "us",
      "xx" => RequestContextContract.default_region,
      "" => RequestContextContract.default_region,
    }.each do |input_region, expected_region|
      reset!
      user = clients(:one)
      token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

      post sign_app_sign_out_url(ri: input_region, host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
           headers: browser_headers.merge(
             "Host" => ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
             "X-TEST-CURRENT-USER" => user.id.to_s,
             "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
           )

      assert_response :success
      location = URI.parse(handoff_form["action"])
      query = Rack::Utils.parse_nested_query(location.query.to_s)

      assert_equal "/oidc/logout", location.path
      assert_equal expected_region, handoff_input_value("ri")
      assert_includes query.fetch("post_logout_redirect_uri"), "ri=#{expected_region}"
      assert_predicate token.reload, :revoked?
    end
  end

  test "transaction issuance failure renders not completed response without local cleanup" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!
    rejected = AcmeLogoutTransactionService::Result.new(
      transaction: nil,
      status: :rejected,
      error: "invalid_request",
      error_description: "completion destination is not allowlisted",
    )

    AcmeLogoutTransactionService.stub(:issue!, rejected) do
      post sign_app_sign_out_url(ri: "us", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
           headers: browser_headers.merge(
             "Host" => ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
             "X-TEST-CURRENT-USER" => user.id.to_s,
             "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
           )
    end

    assert_response :unprocessable_content
    assert_predicate token.reload, :currently_usable?
    assert_not_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
    assert_includes response.body, I18n.t("sign.shared.sign_out.unavailable_title")
    assert_select "form[action*=?][method=?]", sign_app_sign_out_path, "post"
  end

  test "coordination hops on the acme relay auto-advance without a second confirmation" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post sign_app_sign_out_url(ri: "jp", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
         headers: browser_headers.merge(
           "Host" => ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
           "X-TEST-CURRENT-USER" => user.id.to_s,
           "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
         )

    logout_challenge = handoff_input_value("logout_challenge")

    post acme_app_oidc_logout_url(
      host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      ri: "jp",
      logout_challenge: logout_challenge,
    ), headers: {
      "Host" => ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      "Origin" => "https://#{ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")}",
      "Sec-Fetch-Site" => "same-site",
    }

    assert_response :see_other
    sign_completion = URI.parse(jump_rt_url_from_location(response.location))

    assert_equal ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"), sign_completion.host
    assert_equal "/sign/out/complete", sign_completion.path

    get complete_sign_app_sign_out_url(
      host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
      ri: "jp",
    )

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end

  test "acme relay post rejects missing fetch metadata before cleanup" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post sign_app_sign_out_url(ri: "jp", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
         headers: browser_headers.merge(
           "Host" => ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
           "X-TEST-CURRENT-USER" => user.id.to_s,
           "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
         )

    logout_challenge = handoff_input_value("logout_challenge")

    post acme_app_oidc_logout_url(
      host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      ri: "jp",
      logout_challenge: logout_challenge,
    ), headers: {
      "Host" => ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      "Origin" => "https://#{ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")}",
    }

    assert_response :forbidden
    assert_equal "origin_cleared",
                 AcmeLogoutTransactionService.find_by!(logout_challenge: logout_challenge).completed_steps.last
  end

  test "acme relay post rejects untrusted same-site origin before cleanup" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post sign_app_sign_out_url(ri: "jp", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
         headers: browser_headers.merge(
           "Host" => ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
           "X-TEST-CURRENT-USER" => user.id.to_s,
           "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
         )

    logout_challenge = handoff_input_value("logout_challenge")

    post acme_app_oidc_logout_url(
      host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      ri: "jp",
      logout_challenge: logout_challenge,
    ), headers: {
      "Host" => ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      "Origin" => "https://evil.umaxica.app",
      "Sec-Fetch-Site" => "same-site",
    }

    assert_response :forbidden
    assert_equal "origin_cleared",
                 AcmeLogoutTransactionService.find_by!(logout_challenge: logout_challenge).completed_steps.last
  end

  test "coordination edit hop rejects without mutating the sign session" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!
    transaction = AcmeLogoutTransactionService.issue!(
      origin_surface: "acme",
      initiating_client_id: "acme-app",
      completion_url: AcmeLogoutTransactionService.completion_url_for(origin_surface: "acme", ri: "jp"),
      actor_ref: user.public_id,
      session_ref: token.public_id,
    ).transaction
    AcmeLogoutTransactionService.advance!(
      logout_challenge: transaction.logout_challenge,
      step: "origin_cleared",
    )

    get edit_sign_app_sign_out_url(
      host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
      ri: "jp",
      logout_challenge: transaction.logout_challenge,
    ),
        headers: browser_headers.merge(
          "Host" => ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
          "X-TEST-CURRENT-USER" => user.id.to_s,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        )

    assert_response :unprocessable_content
    assert_select "h1", text: I18n.t("sign.shared.sign_out.unavailable_title")
    assert_predicate token.reload, :currently_usable?
    assert_equal "origin_cleared", transaction.reload.completed_steps.last
  end

  test "coordination edit hop rejects an invalid challenge without mutating the sign session" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    get edit_sign_app_sign_out_url(
      host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
      ri: "jp",
      logout_challenge: "invalid-challenge",
    ),
        headers: browser_headers.merge(
          "Host" => ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
          "X-TEST-CURRENT-USER" => user.id.to_s,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        )

    assert_response :unprocessable_content
    assert_select "h1", text: I18n.t("sign.shared.sign_out.unavailable_title")
    assert_predicate token.reload, :currently_usable?
  end

  test "coordination post hop revokes the sign session and advances the challenge" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!
    transaction = AcmeLogoutTransactionService.issue!(
      origin_surface: "acme",
      initiating_client_id: "acme-app",
      completion_url: AcmeLogoutTransactionService.completion_url_for(origin_surface: "acme", ri: "jp"),
      actor_ref: user.public_id,
      session_ref: token.public_id,
    ).transaction
    AcmeLogoutTransactionService.advance!(
      logout_challenge: transaction.logout_challenge,
      step: "origin_cleared",
    )

    post sign_app_sign_out_url(
      host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
      ri: "jp",
      logout_challenge: transaction.logout_challenge,
    ),
         headers: browser_headers.merge(
           "Host" => ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
           "Origin" => "https://#{ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")}",
           "Sec-Fetch-Site" => "same-site",
           "X-TEST-CURRENT-USER" => user.id.to_s,
           "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
         )

    assert_response :see_other
    location = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), location.host
    assert_equal "/sign/out/complete", location.path
    assert_empty query.except("ri")
    assert_predicate token.reload, :revoked?
    assert_predicate token.device_session.reload, :revoked?
    assert_equal "finalized", transaction.reload.completed_steps.last
    assert_predicate transaction.reload, :finalized?
  end

  test "coordination post rejects missing fetch metadata before cleanup" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!
    transaction = AcmeLogoutTransactionService.issue!(
      origin_surface: "acme",
      initiating_client_id: "acme-app",
      completion_url: AcmeLogoutTransactionService.completion_url_for(origin_surface: "acme", ri: "jp"),
      actor_ref: user.public_id,
      session_ref: token.public_id,
    ).transaction
    AcmeLogoutTransactionService.advance!(logout_challenge: transaction.logout_challenge, step: "origin_cleared")

    post sign_app_sign_out_url(
      host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
      ri: "jp",
      logout_challenge: transaction.logout_challenge,
    ),
         headers: browser_headers.merge(
           "Host" => ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
           "Origin" => "https://#{ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")}",
           "X-TEST-CURRENT-USER" => user.id.to_s,
           "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
         )

    assert_response :forbidden
    assert_predicate token.reload, :currently_usable?
    assert_equal "origin_cleared", transaction.reload.completed_steps.last
  end

  test "coordination post rejects untrusted same-site origin before cleanup" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!
    transaction = AcmeLogoutTransactionService.issue!(
      origin_surface: "acme",
      initiating_client_id: "acme-app",
      completion_url: AcmeLogoutTransactionService.completion_url_for(origin_surface: "acme", ri: "jp"),
      actor_ref: user.public_id,
      session_ref: token.public_id,
    ).transaction
    AcmeLogoutTransactionService.advance!(logout_challenge: transaction.logout_challenge, step: "origin_cleared")

    post sign_app_sign_out_url(
      host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
      ri: "jp",
      logout_challenge: transaction.logout_challenge,
    ),
         headers: browser_headers.merge(
           "Host" => ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
           "Origin" => "https://evil.umaxica.app",
           "Sec-Fetch-Site" => "same-site",
           "X-TEST-CURRENT-USER" => user.id.to_s,
           "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
         )

    assert_response :forbidden
    assert_predicate token.reload, :currently_usable?
    assert_equal "origin_cleared", transaction.reload.completed_steps.last
  end

  test "post sign out without a resolved session still starts the coordinated logout" do
    user = clients(:one)

    post sign_app_sign_out_url(ri: "jp", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
         headers: browser_headers.merge(
           "Host" => ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
           "X-TEST-CURRENT-USER" => user.id.to_s,
         )

    assert_response :success
    logout_uri = URI.parse(handoff_form["action"])

    assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), logout_uri.host
    assert_equal "/oidc/logout", logout_uri.path
    assert_predicate handoff_input_value("logout_challenge"), :present?
  end

  private

  def assert_sign_out_handoff_markup(action_path:)
    assert_select "form#sign-out-handoff-form[method=post][data-turbo=false]", 1
    form = css_select("form#sign-out-handoff-form").first
    assert_equal action_path, form["action"]
    assert_select "form#sign-out-handoff-form input[name=authenticity_token]", 0
    assert_select "form#sign-out-handoff-form noscript input[type=submit][value=?]",
                  I18n.t("sign.shared.sign_out.handoff_button"),
                  0
    assert_select "noscript button[form=sign-out-handoff-form][type=submit]", 1
    script = css_select("script").find { |node| node.text.include?('document.getElementById("sign-out-handoff-form")') }
    assert script, "missing sign-out handoff auto-submit script"
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
