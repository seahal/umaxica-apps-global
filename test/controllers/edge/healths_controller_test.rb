# typed: false
# frozen_string_literal: true

require "test_helper"

class EdgeHealthsControllerTest < ActiveSupport::TestCase
  CONTROLLERS = [
    Apex::App::Edge::V0::HealthsController,
    Apex::Com::Edge::V0::HealthsController,
    Apex::Org::Edge::V0::HealthsController,
    Sign::App::Edge::V0::HealthsController,
    Sign::Org::Edge::V0::HealthsController,
  ].freeze

  test "show delegates to show_json on each edge health controller" do
    CONTROLLERS.each do |controller_class|
      controller = controller_class.new
      invoked = false

      controller.stub(:show_json, -> { invoked = true }) do
        controller.show
      end

      assert_predicate invoked, :itself, controller_class.name
    end
  end
end
