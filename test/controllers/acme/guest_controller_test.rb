# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeGuestControllerTest < ActiveSupport::TestCase
  fixtures_none!

  test "acme surfaces do not define guest controller boundaries" do
    assert_not Acme::App.const_defined?(:GuestController, false)
    assert_not Acme::Com.const_defined?(:GuestController, false)
    assert_not Acme::Org.const_defined?(:GuestController, false)
    assert_not Acme::Dev.const_defined?(:GuestController, false)
    assert_not Acme::Net.const_defined?(:GuestController, false)
  end
end
