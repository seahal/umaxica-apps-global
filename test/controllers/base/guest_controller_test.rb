# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BaseGuestControllerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "base surfaces do not define guest controller boundaries" do
    assert_not Base::App.const_defined?(:GuestController, false)
    assert_not Base::Com.const_defined?(:GuestController, false)
    assert_not Base::Org.const_defined?(:GuestController, false)
    assert_not Base::Dev.const_defined?(:GuestController, false)
    assert_not Base::Net.const_defined?(:GuestController, false)
  end
end
