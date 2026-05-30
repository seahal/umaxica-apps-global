# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::RouteNamingTest < ActionDispatch::IntegrationTest
  SURFACES = {
    app: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
    com: ENV.fetch("ID_CORPORATE_URL", "id.com.localhost"),
    org: ENV.fetch("ID_STAFF_URL", "id.org.localhost"),
  }.freeze

  test "top-level sign entry route helpers keep the public sign paths" do
    assert_equal "/sign/in/new", new_sign_app_sign_in_path
    assert_equal "/sign/up/new", new_sign_app_sign_up_path
    assert_equal "/sign/out", sign_app_sign_out_path
    assert_equal "/sign/out/edit", edit_sign_app_sign_out_path
  end

  test "top-level sign routes use natural controller names on every sign surface" do
    SURFACES.each do |surface, host|
      assert_recognizes_top_level_sign_route(surface, host, "/sign/in/new", "sign_ins", "new")
      assert_recognizes_top_level_sign_route(surface, host, "/sign/up/new", "sign_ups", "new")
      assert_recognizes_top_level_sign_route(surface, host, "/sign/out", "sign_outs", "show")
      assert_recognizes_top_level_sign_route(surface, host, "/sign/out/edit", "sign_outs", "edit")
    end
  end

  private

  def assert_recognizes_top_level_sign_route(surface, host, path, controller_name, action)
    route = Rails.application.routes.recognize_path("https://#{host}#{path}", method: :get)

    assert_equal "sign/#{surface}/#{controller_name}", route.fetch(:controller)
    assert_equal action, route.fetch(:action)
  end
end
