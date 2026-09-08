# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageThresholdCredentialInventoryTest < ActiveSupport::TestCase
  test "credential inventory result predicates describe populated credential sets" do
    result = AuthenticationCredentialInventory::Result.new(
      actor: nil, excluding: nil, aal1_methods: [:email],
      aal2_methods: [:totp], aal3_methods: [:passkey],
      step_up_methods: [:passkey], uv_step_up_methods: [:passkey],
      contact_identifiers: [:email], phishing_resistant_methods: [:passkey],
    )

    assert_equal [:email], result.login_methods
    assert_equal 1, result.aal1_method_count
    assert_equal 1, result.aal2_method_count
    assert_equal 1, result.aal3_method_count
    assert_equal 1, result.contact_identifier_count
    assert_equal 1, result.login_method_count
    assert_equal 1, result.step_up_method_count
    assert_predicate result, :aal1_available?
    assert_predicate result, :aal2_available?
    assert_predicate result, :aal3_available?
    assert_predicate result, :contactable?
    assert_predicate result, :login_available?
    assert_predicate result, :step_up_available?
    assert_predicate result, :retains_aal1?
    assert_predicate result, :retains_aal2?
    assert_predicate result, :retains_aal3?
    assert_predicate result, :retains_contactability?
    assert_predicate result, :retains_login?
    assert_predicate result, :retains_step_up?
    assert_predicate result, :retains_uv_step_up?
    assert_not_predicate result, :last_aal1_method?
    assert_not_predicate result, :last_aal2_method?
    assert_not_predicate result, :last_contact_identifier?
    assert_not_predicate result, :last_login_method?
    assert_not_predicate result, :last_step_up_method?
    assert_predicate result, :removable_aal1_credential?
    assert_predicate result, :removable_aal2_credential?
    assert_predicate result, :removable_contact_identifier?
    assert_predicate result, :removable_login_credential?
    assert_predicate result, :removable_step_up_credential?
  end

  test "empty credential inventory identifies last methods" do
    result = AuthenticationCredentialInventory::Result.new(
      actor: nil, excluding: nil, aal1_methods: [],
      aal2_methods: [], aal3_methods: [], step_up_methods: [],
      uv_step_up_methods: [], contact_identifiers: [], phishing_resistant_methods: [],
    )

    assert_predicate result, :last_aal1_method?
    assert_predicate result, :last_aal2_method?
    assert_predicate result, :last_contact_identifier?
    assert_predicate result, :last_login_method?
    assert_predicate result, :last_step_up_method?
    assert_not_predicate result, :removable_aal1_credential?
    assert_not_predicate result, :removable_aal2_credential?
    assert_not_predicate result, :removable_contact_identifier?
    assert_not_predicate result, :removable_login_credential?
    assert_not_predicate result, :removable_step_up_credential?
    assert_not_predicate result, :retains_uv_step_up?
  end
end
