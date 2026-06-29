# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class AuthenticationAccessPolicyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  Context = AuthenticationBase::AccessPolicyContext

  test "public strict allows anonymous and authenticated requests" do
    assert_predicate policy(logged_in: false), :public_strict?
    assert_predicate policy(logged_in: true), :public_strict?
  end

  test "auth required allows only logged in requests" do
    assert_not_predicate policy(logged_in: false), :auth_required?
    assert_predicate policy(logged_in: true), :auth_required?
  end

  test "guest only allows anonymous and deactivated resources" do
    assert_predicate policy(logged_in: false), :guest_only?
    assert_not_predicate policy(logged_in: true), :guest_only?
    assert_predicate policy(logged_in: true, current_resource_deactivated: true), :guest_only?
  end

  private

  def policy(logged_in:, current_resource_deactivated: false)
    Authentication::AccessPolicy.new(
      Context.new(
        policy: :public_strict,
        options: {},
        controller_name: "TestController",
        action_name: "index",
        logged_in: logged_in,
        current_resource_deactivated: current_resource_deactivated,
      ),
      user: nil,
    )
  end
end
