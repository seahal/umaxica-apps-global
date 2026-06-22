# typed: false
# frozen_string_literal: true

require "test_helper"

module Palm
  module App
    class SignOutsControllerTest < ActionDispatch::IntegrationTest
      fixtures :clients, :client_token_kinds

      PALM_HOST = ENV.fetch("PALM_SERVICE_URL", "palm.app.localhost")

      setup do
        host! PALM_HOST
      end

      test "get sign out renders completion when the logout transaction is finalized" do
        transaction = AcmeLogoutTransaction.create!(
          origin_surface: "palm",
          initiating_client_id: "app-ios-rp",
          completion_url: AcmeLogoutTransactionService.completion_url_for(origin_surface: "palm"),
          actor_ref: clients(:one).public_id,
          session_ref: "session-public-id",
          callback_state: "client-state",
          expected_step: AcmeLogoutTransaction.step_sequence_for("palm").first,
          status: AcmeLogoutTransaction::STATUS_FINALIZED,
          expires_at: 10.minutes.from_now,
          completed_steps: %w(origin_cleared acme_cleared sign_cleared finalized),
        )

        get palm_app_sign_out_url(
          logout_challenge: transaction.logout_challenge,
          state: "client-state",
        )

        assert_response :success
        assert_select "h1", text: "Signed out"
        assert_select "code", text: "client-state"
      end

      test "post sign out revokes the current bearer token and returns opaque browser launch data" do
        native_client = clients(:one)
        native_token = create_client_token(native_client)
        access_token = encode_palm_access_token(native_client, native_token)

        post palm_app_sign_out_url,
             headers: bearer_headers(access_token, host: PALM_HOST)

        assert_response :success
        payload = response.parsed_body

        assert_predicate payload["logout_url"], :present?
        assert_predicate payload["state"], :present?
        assert_predicate payload["expires_at"], :present?
        assert_predicate native_token.reload, :revoked?

        logout_uri = URI.parse(payload["logout_url"])
        query = Rack::Utils.parse_nested_query(logout_uri.query.to_s)

        assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), logout_uri.host
        assert_equal "/oidc/logout", logout_uri.path
        assert_predicate query["logout_challenge"], :present?
        assert_nil query["actor_ref"]
        assert_nil query["session_ref"]

        browser_token = create_client_token(native_client)
        acme_headers = as_user_headers(
          native_client,
          host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
          session_public_id: browser_token.public_id,
        )
        sign_headers = as_user_headers(
          native_client,
          host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
          session_public_id: browser_token.public_id,
        )

        get acme_app_oidc_logout_url(
          host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
          ri: "jp",
          logout_challenge: query["logout_challenge"],
        ), headers: acme_headers

        assert_response :success
        assert_select "form[action*=?][method=?]", acme_app_oidc_logout_path, "post"

        post acme_app_oidc_logout_url(
          host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
          ri: "jp",
          logout_challenge: query["logout_challenge"],
        ), headers: acme_headers

        assert_response :see_other
        sign_uri = URI.parse(jump_rt_url_from_location(response.location))
        assert_equal ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"), sign_uri.host
        assert_equal "/sign/out/edit", sign_uri.path

        get edit_sign_app_sign_out_url(
          host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
          ri: "jp",
          logout_challenge: query["logout_challenge"],
        ), headers: sign_headers

        assert_response :success
        assert_select "form[action*=?][method=?]", sign_app_sign_out_path, "post"

        post sign_app_sign_out_url(
          host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
          ri: "jp",
          logout_challenge: query["logout_challenge"],
        ), headers: sign_headers

        assert_response :see_other
        acme_finalize_uri = URI.parse(jump_rt_url_from_location(response.location))
        assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), acme_finalize_uri.host
        assert_equal "/oidc/logout", acme_finalize_uri.path

        post acme_app_oidc_logout_url(
          host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
          ri: "jp",
          logout_challenge: query["logout_challenge"],
        ), headers: acme_headers

        assert_response :see_other
        finalize_uri = URI.parse(jump_rt_url_from_location(response.location))
        finalize_query = Rack::Utils.parse_nested_query(finalize_uri.query.to_s)

        assert_equal "/sign/out/edit", finalize_uri.path
        assert_predicate finalize_query["logout_challenge"], :present?
      end

      private

      def create_client_token(client)
        ClientToken.create!(
          user: client,
          user_token_kind_id: ClientTokenKind::BROWSER_WEB,
          oidc_sid: SecureRandom.uuid,
          oidc_jti: SecureRandom.uuid,
          oidc_client_id: "app-ios-rp",
        )
      end

      def encode_palm_access_token(client, token)
        AuthenticationTokenService.encode(
          client,
          host: OidcIssuer.host_for_resource_type("client"),
          resource_type: "client",
          session_public_id: token.oidc_sid,
          session_id: token.oidc_sid,
          expires_at: 10.minutes.from_now,
          scopes: %w(openid palm.read),
          issuer: OidcIssuer.for_resource_type("client"),
          audiences: [PalmAccessTokenAuthenticator::AUDIENCE],
          subject: OidcSubject.for(client, resource_type: "client"),
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
          client_id: "app-ios-rp",
          oidc_sid: token.oidc_sid,
          oidc_jti: token.oidc_jti,
        )
      end
    end
  end
end
