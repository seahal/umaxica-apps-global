# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::PreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
  end

  test "should get show" do
    get sign_org_preference_url(ri: "jp")

    assert_response :success
    assert_select "a[href=?]", edit_sign_org_preference_region_path(ri: "jp")
  end
end
