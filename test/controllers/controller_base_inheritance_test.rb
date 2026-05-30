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
    Core::App::BareController,
    Core::Com::BareController,
    Core::Org::BareController,
    Sign::App::BareController,
    Sign::Com::BareController,
    Sign::Org::BareController,
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
  ].freeze

  test "bare controllers inherit directly from ActionController base" do
    BARE_CONTROLLERS.each do |controller|
      assert_equal ActionController::Base, controller.superclass,
                   "#{controller.name} must bypass ApplicationController and its callbacks"
      assert_not_operator controller, :<, controller.module_parent::ApplicationController
      assert_includes controller.ancestors, RateLimit
    end
  end

  test "bare controller source does not normalize inheritance to application controller" do
    violations =
      Rails.root.glob("app/controllers/**/bare_controller.rb").filter_map do |path|
        content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
        path.relative_path_from(Rails.root).to_s if content.include?("class BareController < ApplicationController")
      end

    assert_empty violations,
                 "BareController must inherit ActionController::Base directly:\n#{violations.join("\n")}"
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
    ].each do |namespace|
      assert_not namespace.const_defined?(:OpenController, false), namespace.name
    end
  end
end
