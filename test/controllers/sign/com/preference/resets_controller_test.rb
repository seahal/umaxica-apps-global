# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Com
    module Preference
      class ResetsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
          @acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
          host! @host
        end

        test "sign reset edit redirects to acme preference authority" do
          assert_no_difference("ComPreference.count") do
            get edit_sign_com_preference_reset_url(ri: "jp", lx: "en")
          end

          assert_redirected_to edit_acme_com_preference_reset_url(ri: "jp", lx: "en", host: @acme_host)
        end

        test "sign reset mutation redirects without local preference authority" do
          assert_no_difference("ComPreference.count") do
            delete sign_com_preference_reset_url(ri: "jp"), params: { preference_reset: { option_id: "test" } }
          end

          assert_redirected_to acme_com_preference_reset_url(ri: "jp", host: @acme_host)
        end
      end
    end
  end
end
