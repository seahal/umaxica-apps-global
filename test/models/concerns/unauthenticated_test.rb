# typed: false
# frozen_string_literal: true

require "test_helper"

class UnauthenticatedTest < ActiveSupport::TestCase
  test "represents the anonymous authentication state" do
    assert_same Unauthenticated, Unauthenticated.instance
    assert_nil Unauthenticated.id
    assert_not Unauthenticated.user?
    assert_not Unauthenticated.visitor?
    assert_not Unauthenticated.staff?
    assert_predicate Unauthenticated, :unauthenticated?
    assert_not Unauthenticated.authenticated?
  end
end
