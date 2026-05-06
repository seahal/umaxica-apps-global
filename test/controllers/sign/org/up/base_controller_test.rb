# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Up::BaseControllerTest < ActionDispatch::IntegrationTest
  test "after_login_path returns sign_org_configuration_path if available" do
    controller = Sign::Org::Up::BaseController.new

    # Stub the sign_org_configuration_path to simulate routing
    controller.define_singleton_method(:sign_org_configuration_path) { "/org/configuration" }

    assert_equal "/org/configuration", controller.send(:after_login_path)
  end

  test "after_login_path rescues StandardError and returns root path" do
    controller = Sign::Org::Up::BaseController.new

    # raise error to simulate route missing
    controller.define_singleton_method(:sign_org_configuration_path) { raise StandardError, "route missing" }

    assert_equal "/", controller.send(:after_login_path)
  end
end
