# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::PreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
  end

  test "should get show" do
    assert_no_difference("ComPreference.count") do
      get sign_com_preference_url(ri: "jp")
    end

    assert_response :success
    assert_select "a[href*='/preference/email']", count: 0
  end

  test "show uses explicit English locale for all preference labels" do
    get sign_com_preference_url(ri: "us", lx: "en", ct: "dr")

    assert_response :success
    assert_select "html[lang='en']"
    assert_select "span", text: "R18 Display Stopper"
    assert_select "span", text: "R18表示設定", count: 0
  end
end
