# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::PreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    host! @host
  end

  test "sign preference root redirects to acme preference authority" do
    assert_no_difference("AppPreference.count") do
      get sign_app_preference_url(ri: "jp", lx: "en")
    end

    assert_redirected_to acme_app_preference_url(ri: "jp", lx: "en", host: @acme_host)
  end
end
