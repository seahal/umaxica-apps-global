# frozen_string_literal: true

require "test_helper"

module Palm
  module App
    module Api
      module V0
        class ProfilesControllerTest < ActionDispatch::IntegrationTest
          HOST = ENV.fetch("PALM_SERVICE_URL", "palm-jp.umaxica.app")

          setup do
            host! HOST
            https!
          end

          test "requires bearer token" do
            get "/api/v0/profile", headers: json_headers

            assert_response :unauthorized
            assert_equal "authentication_required", response.parsed_body.dig("error", "code")
            assert_predicate response.parsed_body.dig("error", "request_id"), :present?
          end

          test "returns current client profile for valid palm bearer token without setting cookies" do
            token = palm_token

            get "/api/v0/profile", headers: json_headers.merge("Authorization" => "Bearer #{token}")

            assert_response :success
            assert_equal({ "type" => "client", "id" => clients(:one).public_id }, response.parsed_body.fetch("actor"))
            assert_empty response_set_cookie_lines
            assert_includes response.headers["Cache-Control"], "no-store"
            assert_not_includes response.body, token
          end

          test "rejects core browser audience token" do
            get(
              "/api/v0/profile",
              headers: json_headers.merge("Authorization" => "Bearer #{palm_token(audiences: ["core-browser"])}"),
            )

            assert_response :unauthorized
            assert_equal "authentication_required", response.parsed_body.dig("error", "code")
          end

          test "does not authenticate from cookie transport" do
            cookies[CoreBrowserCredentialContract::ACCESS_COOKIE] = palm_token

            get "/api/v0/profile", headers: json_headers

            assert_response :unauthorized
            assert_equal "authentication_required", response.parsed_body.dig("error", "code")
          end

          test "rejects dpop scheme for this bearer boundary" do
            get "/api/v0/profile", headers: json_headers.merge("Authorization" => "DPoP #{palm_token}")

            assert_response :unauthorized
            assert_equal "authentication_required", response.parsed_body.dig("error", "code")
          end

          private

          def json_headers
            {
              "Accept" => "application/json",
              "Content-Type" => "application/json",
              "Client-Agent" => AuthHelpers::MODERN_USER_AGENT,
            }
          end

          def palm_token(client: clients(:one), scopes: %w(openid palm.read),
                         audiences: [PalmAccessTokenAuthenticator::AUDIENCE], client_id: "app-ios-rp")
            AuthenticationTokenService.encode(
              client,
              host: OidcIssuer.host_for_resource_type("client"),
              resource_type: "client",
              session_public_id: "palm-session",
              session_id: "palm-session",
              expires_at: 10.minutes.from_now,
              scopes: scopes,
              issuer: OidcIssuer.for_resource_type("client"),
              audiences: audiences,
              subject: OidcSubject.for(client, resource_type: "client"),
              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
              client_id: client_id,
            )
          end
        end
      end
    end
  end
end
