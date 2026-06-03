# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::PreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    host! @host
  end

  test "sign preference root redirects to acme preference authority" do
    assert_no_difference("ComPreference.count") do
      get sign_com_preference_url(ri: "jp", lx: "en")
    end

    assert_redirected_to acme_com_preference_url(ri: "jp", lx: "en", host: @acme_host)
  end
end
