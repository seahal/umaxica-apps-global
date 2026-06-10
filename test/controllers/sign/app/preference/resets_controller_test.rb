# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module App
    module Preference
      class ResetsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
          @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
          host! @host
        end

        test "sign reset edit redirects to acme preference authority" do
          assert_no_difference("AppPreference.count") do
            get edit_sign_app_preference_reset_url(ri: "jp", lx: "en")
          end

          assert_redirected_to edit_acme_app_preference_reset_url(ri: "jp", lx: "en", host: @acme_host)
        end

        test "sign reset mutation redirects without local preference authority" do
          assert_no_difference("AppPreference.count") do
            post sign_app_preference_reset_attempt_url(ri: "jp"), params: { preference_reset: { option_id: "test" } }
          end

          assert_redirected_to "http://#{@acme_host}/preference/reset_attempt?ri=jp"
        end
      end
    end
  end
end
