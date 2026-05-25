# typed: false
# frozen_string_literal: true

require "test_helper"

class ControllerBaseInheritanceTest < ActiveSupport::TestCase
  fixtures_none!

  OPEN_CONTROLLERS = [
    Apex::App::OpenController,
    Apex::Com::OpenController,
    Apex::Org::OpenController,
    Sign::App::OpenController,
    Sign::Com::OpenController,
    Sign::Org::OpenController,
    Jump::App::OpenController,
    Jump::Com::OpenController,
    Jump::Org::OpenController,
  ].freeze

  APPLICATION_CONTROLLERS = [
    Apex::App::ApplicationController,
    Apex::Com::ApplicationController,
    Apex::Org::ApplicationController,
    Sign::App::ApplicationController,
    Sign::Com::ApplicationController,
    Sign::Org::ApplicationController,
    Jump::App::ApplicationController,
    Jump::Com::ApplicationController,
    Jump::Org::ApplicationController,
  ].freeze

  test "open controllers inherit directly from ActionController base" do
    OPEN_CONTROLLERS.each do |controller|
      assert_equal ActionController::Base, controller.superclass
      assert_includes controller.ancestors, RateLimit
    end
  end

  test "surface application controllers inherit directly from ActionController base" do
    APPLICATION_CONTROLLERS.each do |controller|
      assert_equal ActionController::Base, controller.superclass
      assert_includes controller.ancestors, RateLimit
    end
  end
end
