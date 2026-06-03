# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::PreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @acme_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    host! @host
  end

  test "sign preference root redirects to acme preference authority" do
    assert_no_difference("OrgPreference.count") do
      get sign_org_preference_url(ri: "jp", lx: "en")
    end

    assert_redirected_to acme_org_preference_url(ri: "jp", lx: "en", host: @acme_host)
  end
end
