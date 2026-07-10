# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceBootstrapIdempotencyTest < ActionDispatch::IntegrationTest
  test "cookie-less first GET bootstraps preference and cookie-backed second GET does not create another parent" do
    host! "base.app.localhost"

    assert_difference -> { AppPreference.count }, 1 do
      get "/preference?ri=jp"
    end
    assert_response :success

    assert_no_difference -> { AppPreference.count } do
      get "/preference?ri=jp"
    end
    assert_response :success
  end
end
