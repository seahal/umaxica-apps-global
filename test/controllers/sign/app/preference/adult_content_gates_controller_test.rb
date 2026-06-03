# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module App
    module Preference
      class AdultContentGatesControllerTest < ActionDispatch::IntegrationTest
        setup do
          @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
          @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
          host! @host
        end

        test "sign adult_content_gate edit redirects to acme preference authority" do
          assert_no_difference("AppPreference.count") do
            get edit_sign_app_preference_adult_content_gate_url(ri: "jp", lx: "en")
          end

          assert_redirected_to edit_acme_app_preference_adult_content_gate_url(ri: "jp", lx: "en", host: @acme_host)
        end

        test "sign adult_content_gate mutation redirects without local preference authority" do
          assert_no_difference("AppPreference.count") do
            patch sign_app_preference_adult_content_gate_url(ri: "jp"),
                  params: { preference_adult_content_gate: { option_id: "test" } }
          end

          assert_redirected_to acme_app_preference_adult_content_gate_url(ri: "jp", host: @acme_host)
        end
      end
    end
  end
end
