# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Org
    module Preference
      class LanguagesControllerTest < ActionDispatch::IntegrationTest
        setup do
          @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
          @acme_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
          host! @host
        end

        test "sign language edit redirects to acme preference authority" do
          assert_no_difference("OrgPreference.count") do
            get edit_sign_org_preference_language_url(ri: "jp", lx: "en")
          end

          assert_redirected_to edit_acme_org_preference_language_url(ri: "jp", lx: "en", host: @acme_host)
        end

        test "sign language mutation redirects without local preference authority" do
          assert_no_difference("OrgPreference.count") do
            patch sign_org_preference_language_url(ri: "jp"), params: { preference_language: { option_id: "test" } }
          end

          assert_redirected_to acme_org_preference_language_url(ri: "jp", host: @acme_host)
        end
      end
    end
  end
end
