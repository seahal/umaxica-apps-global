# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Com
    module Preference
      class CookiesControllerTest < ActionDispatch::IntegrationTest
        setup do
          @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
          @acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
          host! @host
        end

        test "sign cookie edit redirects to acme preference authority" do
          assert_no_difference("ComPreference.count") do
            get edit_sign_com_preference_cookie_url(ri: "jp", lx: "en")
          end

          assert_redirected_to edit_acme_com_preference_cookie_url(ri: "jp", lx: "en", host: @acme_host)
        end

        test "sign cookie mutation redirects without local preference authority" do
          assert_no_difference("ComPreference.count") do
            patch sign_com_preference_cookie_url(ri: "jp"), params: { preference_cookie: { option_id: "test" } }
          end

          assert_redirected_to acme_com_preference_cookie_url(ri: "jp", host: @acme_host)
        end
      end
    end
  end
end
