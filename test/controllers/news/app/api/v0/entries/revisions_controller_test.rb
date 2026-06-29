# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class News::App::Api::V0::Entries::RevisionsControllerTest < ActionDispatch::IntegrationTest
  test "index renders empty json" do
    host! ENV.fetch("PRIVATE_NEWS_SERVICE_URL")

    get "/api/v0/entries/example/revisions"

    assert_response :success
    assert_equal [], response.parsed_body
  end

  test "show renders empty json" do
    host! ENV.fetch("PRIVATE_NEWS_SERVICE_URL")

    get "/api/v0/entries/example/revisions/rev-1"

    assert_response :success
    assert_equal({}, response.parsed_body)
  end
end
