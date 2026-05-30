# typed: false
# frozen_string_literal: true

require "test_helper"

# Object-level authorization for ClientChronicle activity-log listings.
# index?/show? allow the owning actor types (Client, Visitor) and deny everyone else.
# Row-level ownership (subject_id == current actor) stays enforced by the controller query.
class ClientChroniclePolicyTest < ActiveSupport::TestCase
  fixtures :clients, :operators

  def policy_for(user)
    ClientChroniclePolicy.new(ClientChronicle, user: user)
  end

  test "client may list activity logs" do
    policy = policy_for(clients(:one))

    assert policy.apply(:index?)
    assert policy.apply(:show?)
  end

  test "visitor may list activity logs" do
    visitor = create_verified_visitor_with_email(email_address: "policy-#{SecureRandom.hex(4)}@example.com")
    policy = policy_for(visitor)

    assert policy.apply(:index?)
    assert policy.apply(:show?)
  end

  test "operator may not list client activity logs" do
    policy = policy_for(operators(:one))

    assert_not policy.apply(:index?)
    assert_not policy.apply(:show?)
  end

  test "anonymous actor may not list activity logs" do
    policy = policy_for(nil)

    assert_not policy.apply(:index?)
    assert_not policy.apply(:show?)
  end
end
