# typed: false
# frozen_string_literal: true

require "test_helper"

class SignInCyclePolicyTest < ActiveSupport::TestCase
  test "fail is denied when the record is not a sign-in flow" do
    policy = SignIn::CyclePolicy.new(Object.new, user: clients(:one))

    assert_not policy.fail?
  end

  test "fail is denied when the actor is missing from a bound cycle" do
    record = Object.new
    record.define_singleton_method(:status_id_for) { |_name| 1 }
    record.define_singleton_method(:sign_in_completed?) { false }
    record.define_singleton_method(:sign_in_failed?) { false }
    record.define_singleton_method(:principal_id) { 7 }
    record.define_singleton_method(:token_id) { nil }
    policy = SignIn::CyclePolicy.new(record, user: nil)

    assert_not policy.fail?
  end

  test "actor class matching covers visitor operator and unknown records" do
    visitor_policy = SignIn::CyclePolicy.new(VisitorSignInFlow.allocate, user: visitors(:reserved_visitor))
    operator_policy = SignIn::CyclePolicy.new(OperatorSignInFlow.allocate, user: operators(:one))
    unknown_policy = SignIn::CyclePolicy.new(Object.new, user: clients(:one))

    assert visitor_policy.send(:actor_class_matches?)
    assert operator_policy.send(:actor_class_matches?)
    assert_not unknown_policy.send(:actor_class_matches?)
  end

  test "token matching is false when the current login is blank" do
    record = Object.new
    record.define_singleton_method(:token_id) { "token-1" }
    record.define_singleton_method(:respond_to?) { |name, *| name == :token_id || name == :token || super(name) }
    record.define_singleton_method(:token) { nil }
    policy = SignIn::CyclePolicy.new(record, user: clients(:one))

    assert_not policy.send(:token_matches?)
  end
end
