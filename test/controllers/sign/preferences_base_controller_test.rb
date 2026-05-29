# typed: false
# frozen_string_literal: true

require "test_helper"

class SignPreferencesBaseControllerTest < ActiveSupport::TestCase
  fixtures_none!

  test "preference bases use surface application controllers and ActorSupport" do
    [
      Sign::App::PreferencesBaseController,
      Sign::Com::PreferencesBaseController,
      Sign::Org::PreferencesBaseController,
    ].each do |controller|
      assert_equal controller.module_parent::ApplicationController, controller.superclass
      assert_includes controller.included_modules, ActorSupport
      assert_includes controller.included_modules, ActionPolicy::Controller
    end
  end

  test "open preference bases keep their surface layouts" do
    assert_equal "sign/app/application", Sign::App::Preference::Region::TimesController._layout
    assert_equal "sign/com/application", Sign::Com::Preference::Region::TimesController._layout
    assert_equal "sign/org/application", Sign::Org::Preference::Region::TimesController._layout
  end

  test "preference bases authorize writes after actor resolution" do
    [
      Sign::App::PreferencesBaseController,
      Sign::Com::PreferencesBaseController,
      Sign::Org::PreferencesBaseController,
    ].each do |controller|
      before_filters = controller._process_action_callbacks.select { |callback| callback.kind == :before }.map(&:filter)

      assert_operator before_filters.index(:set_current_actor), :<,
                      before_filters.index(:authorize_preference_write!)
    end
  end
end
