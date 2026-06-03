# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Com
    module Preference
      class AdultContentGatesControllerTest < ActionDispatch::IntegrationTest
        setup do
          @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
          @acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
          host! @host
        end

        test "sign adult_content_gate edit redirects to acme preference authority" do
          assert_no_difference("ComPreference.count") do
            get edit_sign_com_preference_adult_content_gate_url(ri: "jp", lx: "en")
          end

          assert_redirected_to edit_acme_com_preference_adult_content_gate_url(ri: "jp", lx: "en", host: @acme_host)
        end

        test "sign adult_content_gate mutation redirects without local preference authority" do
          assert_no_difference("ComPreference.count") do
            patch sign_com_preference_adult_content_gate_url(ri: "jp"),
                  params: { preference_adult_content_gate: { option_id: "test" } }
          end

          assert_redirected_to acme_com_preference_adult_content_gate_url(ri: "jp", host: @acme_host)
        end
      end
    end
  end
end
