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

  BARE_CONTROLLERS = [
    Apex::App::BareController,
    Apex::Com::BareController,
    Apex::Dev::BareController,
    Apex::Net::BareController,
    Apex::Org::BareController,
    Sign::App::BareController,
    Sign::Com::BareController,
    Sign::Org::BareController,
    Jump::App::BareController,
    Jump::Com::BareController,
    Jump::Org::BareController,
  ].freeze

  APPLICATION_CONTROLLERS = [
    Apex::App::ApplicationController,
    Apex::Com::ApplicationController,
    Apex::Dev::ApplicationController,
    Apex::Net::ApplicationController,
    Apex::Org::ApplicationController,
    Sign::App::ApplicationController,
    Sign::Com::ApplicationController,
    Sign::Org::ApplicationController,
    Jump::App::ApplicationController,
    Jump::Com::ApplicationController,
    Jump::Org::ApplicationController,
  ].freeze

  test "open controllers inherit from their surface application controller" do
    OPEN_CONTROLLERS.each do |controller|
      assert_equal controller.module_parent::ApplicationController, controller.superclass
      assert_includes controller.ancestors, RateLimit
    end
  end

  test "bare controllers inherit directly from ActionController base" do
    BARE_CONTROLLERS.each do |controller|
      assert_equal ActionController::Base, controller.superclass
      assert_not_operator controller, :<, controller.module_parent::ApplicationController
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
