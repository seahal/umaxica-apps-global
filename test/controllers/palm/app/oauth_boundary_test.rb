# typed: false
# frozen_string_literal: true

require "test_helper"

module Palm
  module App
    class OauthBoundaryTest < ActiveSupport::TestCase
      fixtures_none!

      test "palm app exposes reserved callback stubs but no authorize or token endpoint" do
        host = ENV.fetch("PALM_SERVICE_URL", "palm-jp.umaxica.app")

        assert_equal(
          "palm/app/oauth/callbacks#show",
          route_to("https://#{host}/oauth/callback", method: :get),
        )
        assert_equal(
          "palm/app/oauth/callback/ios#index",
          route_to("https://#{host}/oauth/callback/ios", method: :get),
        )
        assert_equal(
          "palm/app/oauth/callback/android#index",
          route_to("https://#{host}/oauth/callback/android", method: :get),
        )

        source = Rails.root.join("config/routes/palm.rb").read

        assert_not_includes source, 'controller: "ios"'
        assert_not_includes source, 'controller: "android"'

        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("https://#{host}/oauth/authorize", method: :get)
        end
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("https://#{host}/oauth/token", method: :post)
        end
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("https://#{host}/api/v0/token/refresh", method: :post)
        end
      end

      test "palm app exposes bearer profile api under the api namespace" do
        host = ENV.fetch("PALM_SERVICE_URL", "palm-jp.umaxica.app")

        assert_equal(
          "palm/app/api/v0/profiles#show",
          route_to("https://#{host}/api/v0/profile", method: :get),
        )
      end

      test "sign does not own native client registration or oauth issuance routes" do
        native_ids = OidcClientRegistry.client_ids.grep(/\Asign.*(?:ios|android|native)|(?:ios|android|native).*sign/i)

        assert_empty native_ids

        sign_host = ENV.fetch("ID_SERVICE_URL", "id.umaxica.app")
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("https://#{sign_host}/oauth/authorize", method: :get)
        end
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("https://#{sign_host}/oauth/token", method: :post)
        end
      end

      private

      def route_to(path, method:)
        Rails.application.routes.recognize_path(path, method: method).values_at(:controller, :action).join("#")
      end
    end
  end
end
