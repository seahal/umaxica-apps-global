# typed: false
# frozen_string_literal: true

require "test_helper"

class Authentication::BaseExtractionTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include Authentication::Base
  end

  test "base includes extracted authentication concerns" do
    assert_includes Harness.included_modules, Authentication::Redirects
    assert_includes Harness.included_modules, Authentication::CookieStore
    assert_includes Harness.included_modules, Authentication::JwtTokens
    assert_includes Harness.included_modules, Authentication::BulletinGate
    assert_includes Harness.included_modules, Authentication::SequenceGate
    assert_includes Harness.included_modules, Authentication::WithdrawalGate
  end

  test "extracted public methods remain public on controllers" do
    assert_operator Harness.public_instance_methods, :include?, :set_login_auth_cookies
    assert_operator Harness.public_instance_methods, :include?, :encode_login_access_token
    assert_operator Harness.public_instance_methods, :include?, :issue_bulletin!
    assert_operator Harness.public_instance_methods, :include?, :sign_in_sequence_redirect_path
  end

  test "extracted private helpers remain private on controllers" do
    assert_operator Harness.private_instance_methods, :include?, :cookie_options
    assert_operator Harness.private_instance_methods, :include?, :set_refresh_auth_cookies
    assert_operator Harness.private_instance_methods, :include?, :encode_refreshed_access_token
    assert_operator Harness.private_instance_methods, :include?, :build_auth_preference_snapshot
    assert_operator Harness.private_instance_methods, :include?, :start_sign_in_flow_for!
  end

  test "extracted concerns do not register process callbacks" do
    filters = Harness._process_action_callbacks.map(&:filter)

    assert_not_includes filters, :set_login_auth_cookies
    assert_not_includes filters, :encode_login_access_token
    assert_not_includes filters, :issue_bulletin!
    assert_not_includes filters, :sign_in_sequence_redirect_path
  end
end
