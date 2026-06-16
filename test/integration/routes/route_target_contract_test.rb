# typed: false
# frozen_string_literal: true

require "test_helper"

class RouteTargetContractTest < ActiveSupport::TestCase
  fixtures_none!

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

  private

  def surface_routes
    Rails.application.routes.routes.select do |route|
      controller = route.defaults[:controller]
      action = route.defaults[:action]

      controller.present? && action.present? && controller.match?(SURFACE_CONTROLLER_PREFIX)
    end
  end
end
