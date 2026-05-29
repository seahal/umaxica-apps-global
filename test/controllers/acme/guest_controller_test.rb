# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeGuestControllerTest < ActiveSupport::TestCase
  fixtures_none!

  GUEST_CONTROLLERS = [
    Acme::App::GuestController,
    Acme::Com::GuestController,
    Acme::Org::GuestController,
  ].freeze

  test "app com and org define guest boundaries under their application controllers" do
    GUEST_CONTROLLERS.each do |controller|
      assert_equal controller.module_parent::ApplicationController, controller.superclass
      assert_not_equal controller.module_parent::BareController, controller.superclass
      assert_not_equal controller.module_parent::PrivateController, controller.superclass
    end
  end

  test "guest boundaries declare unauthorized guest only policy" do
    GUEST_CONTROLLERS.each do |controller|
      rules = controller.local_authentication_mode_rules

      assert_equal :guest, rules.last[:mode]
      assert_equal({ status: :unauthorized }, rules.last[:options])
    end
  end

  test "dev and net do not define guest boundaries yet" do
    assert_not Acme::Dev.const_defined?(:GuestController, false)
    assert_not Acme::Net.const_defined?(:GuestController, false)
  end
end
