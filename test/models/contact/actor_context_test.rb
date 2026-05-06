# typed: false
# frozen_string_literal: true

require "test_helper"

class Contact::ActorContextTest < ActiveSupport::TestCase
  test "guest predicate matches subject type and exposes attributes" do
    context = Contact::ActorContext.new(
      subject_type: "guest",
      subject_id: "customer-1",
      email: "guest@example.com",
      telephone: "+819012345678",
    )

    assert_predicate context, :guest?
    assert_not context.anonymous_member?
    assert_not context.identified_member?
    assert_equal "customer-1", context.subject_id
    assert_equal "guest@example.com", context.email
    assert_equal "+819012345678", context.telephone
  end

  test "anonymous member predicate matches subject type" do
    context = Contact::ActorContext.new(subject_type: "anonymous_member")

    assert_predicate context, :anonymous_member?
    assert_not context.guest?
    assert_not context.identified_member?
  end

  test "identified member predicate matches subject type" do
    context = Contact::ActorContext.new(subject_type: "identified_member")

    assert_predicate context, :identified_member?
    assert_not context.guest?
    assert_not context.anonymous_member?
  end
end
