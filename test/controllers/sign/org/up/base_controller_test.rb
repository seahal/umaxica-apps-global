# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Sign::Up::BaseControllerTest < ActionDispatch::IntegrationTest
  test "after_login_path returns sign_org_settings_path if available" do
    controller = Sign::Org::Sign::Up::BaseController.new

    # Stub the sign_org_settings_path to simulate routing
    controller.define_singleton_method(:sign_org_settings_path) { "/org/settings" }

    assert_equal "/org/settings", controller.send(:after_login_path)
  end

  test "after_login_path raises route errors instead of hiding them" do
    controller = Sign::Org::Sign::Up::BaseController.new

    # raise error to simulate route missing
    controller.define_singleton_method(:sign_org_settings_path) { raise StandardError, "route missing" }

    error =
      assert_raises(StandardError) do
        controller.send(:after_login_path)
      end

    assert_equal "route missing", error.message
  end
end
