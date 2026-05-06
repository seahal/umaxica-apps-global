# typed: false
# frozen_string_literal: true

require "test_helper"

class InertiaExampleControllerTest < ActionDispatch::IntegrationTest
  test "GET /inertia_example returns inertia data" do
    get "/inertia-example"

    assert_response :success
  end
end
