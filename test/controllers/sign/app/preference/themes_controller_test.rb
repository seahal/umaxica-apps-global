# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module App
    module Preference
      class ThemesControllerTest < ActionDispatch::IntegrationTest
        setup do
          @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
          @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
          host! @host
        end

        test "sign theme edit redirects to acme preference authority" do
          assert_no_difference("AppPreference.count") do
            get edit_sign_app_preference_theme_url(ri: "jp", lx: "en")
          end

          assert_redirected_to edit_acme_app_preference_theme_url(ri: "jp", lx: "en", host: @acme_host)
        end

        test "sign theme mutation redirects without local preference authority" do
          assert_no_difference("AppPreference.count") do
            patch sign_app_preference_theme_url(ri: "jp"), params: { preference_theme: { option_id: "test" } }
          end

          assert_redirected_to acme_app_preference_theme_url(ri: "jp", host: @acme_host)
        end
      end
    end
  end
end
