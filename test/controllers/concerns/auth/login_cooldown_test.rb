# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthLoginCooldownTest < ActiveSupport::TestCase
  setup do
    @original_login_cooldown = login_cooldown
    self.login_cooldown = 30.seconds
  end

  teardown do
    self.login_cooldown = @original_login_cooldown
  end

  test "login_cooldown reports the configured window" do
    assert_equal 30.seconds, AuthenticationBase.login_cooldown
  end

  test "LoginCooldownError is a StandardError" do
    assert_operator AuthenticationBase::LoginCooldownError, :<, StandardError
  end
end
