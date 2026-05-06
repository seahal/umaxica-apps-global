# typed: false
# frozen_string_literal: true

require "test_helper"

module Apex
  module App
    class PreferencesControllerTest < ActionDispatch::IntegrationTest
      setup do
        host! ENV.fetch("APEX_SERVICE_URL", "www.app.localhost")
      end

      test "should get show" do
        get "/preference?ri=jp"

        assert_response :success
      end
    end
  end
end
