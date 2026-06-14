# typed: false
# frozen_string_literal: true

require "test_helper"

module Palm
  module App
    module Oauth
      class CallbacksControllerTest < ActionDispatch::IntegrationTest
        # rubocop:disable I18n/RailsI18n/DecorateString
        STATIC_MESSAGE = "This URL is reserved for completing app authentication.\n" \
                         "Open the mobile app and try signing in again."
        # rubocop:enable I18n/RailsI18n/DecorateString

        test "reserved callback stub returns static no-store response without authentication" do
          host = ENV.fetch("PALM_SERVICE_URL", "palm.jp.umaxica.app")

          get palm_app_oauth_callback_url(host: host)

          assert_response :ok
          assert_equal "text/plain", response.media_type
          assert_equal STATIC_MESSAGE, response.body
          assert_equal "no-store", response.headers["Cache-Control"]
          assert_nil response.headers["Set-Cookie"]
        end

        test "platform callback stubs are inert with code and state params" do
          host = ENV.fetch("PALM_SERVICE_URL", "palm.jp.umaxica.app")

          assert_no_oauth_mutation do
            OidcTokenExchangeService.stub(:call, ->(**) { flunk("Palm callback must not call token exchange") }) do
              get palm_app_oauth_ios_callback_url(
                host: host,
                code: "secret-code",
                state: "secret-state",
                access_token: "secret-access-token",
              )
            end
          end

          assert_response :ok
          assert_equal STATIC_MESSAGE, response.body
          assert_not_includes response.body, "secret-code"
          assert_not_includes response.body, "secret-state"
          assert_not_includes response.body, "secret-access-token"
          assert_nil response.headers["Set-Cookie"]

          get palm_app_oauth_android_callback_url(host: host, code: "other-code", state: "other-state")

          assert_response :ok
          assert_equal STATIC_MESSAGE, response.body
          assert_not_includes response.body, "other-code"
          assert_not_includes response.body, "other-state"
          assert_nil response.headers["Set-Cookie"]
        end

        private

        def assert_no_oauth_mutation(&)
          assert_no_difference(
            [
              "ClientAuthorizationCode.count",
              "ClientOidcAuthorizationTransaction.count",
              "ClientOidcConnection.count",
              "ClientToken.count",
            ],
            &
          )
        end
      end
    end
  end
end
