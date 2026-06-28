# typed: false
# frozen_string_literal: true

require "test_helper"

class RouteTargetContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  SURFACE_CONTROLLER_PREFIX = %r{\A(?:acme|sign|core|base|palm|help|docs|news)/}

  test "surface routes reference loadable controllers and routable actions" do
    missing_controllers = []
    missing_actions = []

    surface_routes.each do |route|
      controller_path = route.defaults.fetch(:controller)
      action_name = route.defaults.fetch(:action).to_s
      controller_name = "#{controller_path.camelize}Controller"
      controller = controller_name.constantize

      unless controller.action_methods.include?(action_name)
        missing_actions << "#{controller_path}##{action_name}"
      end
    rescue NameError
      missing_controllers << controller_name
    end

    assert_empty missing_controllers.uniq.sort,
                 "Surface routes reference missing controller classes"
    assert_empty missing_actions.uniq.sort,
                 "Surface routes reference controllers without routable actions"
  end

  test "surface route controllers declare authentication mode explicitly" do
    missing_authentication_modes =
      surface_route_controllers.filter_map do |controller|
        controller.name unless controller.const_defined?(:AUTHENTICATION_MODE, false)
      end

    assert_empty missing_authentication_modes.uniq.sort,
                 "Surface route controllers must declare AUTHENTICATION_MODE on the concrete class"
  end

  private

  def surface_routes
    Rails.application.routes.routes.select do |route|
      controller = route.defaults[:controller]
      action = route.defaults[:action]

      controller.present? && action.present? && controller.match?(SURFACE_CONTROLLER_PREFIX)
    end
  end

  def surface_route_controllers
    surface_routes.map do |route|
      "#{route.defaults.fetch(:controller).camelize}Controller".constantize
    end.uniq
  end
end
