# typed: false
# frozen_string_literal: true

require "test_helper"

class SignRouteHostTest < ActionDispatch::IntegrationTest
  test "sign app routes match ID_SERVICE_URL" do
    with_env("ID_SERVICE_URL" => "sign.app.example.test") do
      Rails.application.reload_routes!
      host!("sign.app.example.test")

      get("http://sign.app.example.test/")

      assert_not_equal 404, response.status
    end
  ensure
    Rails.application.reload_routes!
  end

  test "sign com named root route points at sign/com/roots#index" do
    with_env("ID_CORPORATE_URL" => "sign.com.example.test") do
      Rails.application.reload_routes!

      route = Rails.application.routes.named_routes[:sign_com_root]

      assert_equal "/", route.path.spec.to_s
      assert_equal "sign/com/roots", route.defaults[:controller]
      assert_equal "index", route.defaults[:action]
    end
  ensure
    Rails.application.reload_routes!
  end

  test "sign org routes match ID_STAFF_URL" do
    with_env("ID_STAFF_URL" => "sign.org.example.test") do
      Rails.application.reload_routes!
      host!("sign.org.example.test")

      get("http://sign.org.example.test/")

      assert_not_equal 404, response.status
    end
  ensure
    Rails.application.reload_routes!
  end

  private

  def with_env(vars)
    original = {}
    vars.each_key { |key| original[key] = ENV[key] }

    vars.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    original.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
