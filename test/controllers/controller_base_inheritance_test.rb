# typed: false
# frozen_string_literal: true

require "test_helper"

class ControllerBaseInheritanceTest < ActiveSupport::TestCase
  fixtures_none!

  BARE_CONTROLLERS = [
    Acme::App::BareController,
    Acme::Com::BareController,
    Acme::Dev::BareController,
    Acme::Net::BareController,
    Acme::Org::BareController,
    Sign::App::BareController,
    Sign::Com::BareController,
    Sign::Org::BareController,
    Jump::App::BareController,
    Jump::Com::BareController,
    Jump::Org::BareController,
  ].freeze

  APPLICATION_CONTROLLERS = [
    Acme::App::ApplicationController,
    Acme::Com::ApplicationController,
    Acme::Dev::ApplicationController,
    Acme::Net::ApplicationController,
    Acme::Org::ApplicationController,
    Sign::App::ApplicationController,
    Sign::Com::ApplicationController,
    Sign::Org::ApplicationController,
    Jump::App::ApplicationController,
    Jump::Com::ApplicationController,
    Jump::Org::ApplicationController,
  ].freeze

  test "bare controllers inherit from their surface application controller" do
    BARE_CONTROLLERS.each do |controller|
      assert_equal controller.module_parent::ApplicationController, controller.superclass
      assert_includes controller.ancestors, RateLimit
    end
  end

  test "surface application controllers inherit directly from ActionController base" do
    APPLICATION_CONTROLLERS.each do |controller|
      assert_equal ActionController::Base, controller.superclass
      assert_includes controller.ancestors, RateLimit
    end
  end

  test "legacy open controller compatibility bases are retired" do
    [
      Acme::App,
      Acme::Com,
      Acme::Org,
      Core::App,
      Core::Com,
      Core::Org,
      Sign::App,
      Sign::Com,
      Sign::Org,
      Jump::App,
      Jump::Com,
      Jump::Org,
    ].each do |namespace|
      assert_not namespace.const_defined?(:OpenController, false), namespace.name
    end
  end
end
