# typed: false
# frozen_string_literal: true

require "test_helper"

# Object-level authorization for OperatorChronicle activity-log listings (org surface).
# index?/show? allow only the owning actor type (Operator) and deny everyone else.
# Row-level ownership (subject_id == current operator) stays enforced by the controller query.
class OperatorChroniclePolicyTest < ActiveSupport::TestCase
  fixtures :clients, :operators

  def policy_for(user)
    OperatorChroniclePolicy.new(OperatorChronicle, user: user)
  end

  test "operator may list activity logs" do
    policy = policy_for(operators(:one))

    assert policy.apply(:index?)
    assert policy.apply(:show?)
  end

  test "client may not list operator activity logs" do
    policy = policy_for(clients(:one))

    assert_not policy.apply(:index?)
    assert_not policy.apply(:show?)
  end

  test "visitor may not list operator activity logs" do
    visitor = create_verified_visitor_with_email(email_address: "op-chronicle-#{SecureRandom.hex(4)}@example.com")
    policy = policy_for(visitor)

    assert_not policy.apply(:index?)
    assert_not policy.apply(:show?)
  end

  test "anonymous actor may not list activity logs" do
    policy = policy_for(nil)

    assert_not policy.apply(:index?)
    assert_not policy.apply(:show?)
  end
end
