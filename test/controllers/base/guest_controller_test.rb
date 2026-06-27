# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseGuestControllerTest < ActiveSupport::TestCase
  fixtures_none!

  test "base surfaces do not define guest controller boundaries" do
    assert_not Base::App.const_defined?(:GuestController, false)
    assert_not Base::Com.const_defined?(:GuestController, false)
    assert_not Base::Org.const_defined?(:GuestController, false)
    assert_not Base::Dev.const_defined?(:GuestController, false)
    assert_not Base::Net.const_defined?(:GuestController, false)
  end
end
