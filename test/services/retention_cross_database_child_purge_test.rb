# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class RetentionCrossDatabaseChildPurgeTest < ActiveSupport::TestCase
  test "purge removes cross-database children for a visitor" do
    visitor = Visitor.create!
    VisitorNotificationRecord.create!(visitor: visitor)
    VisitorAccount.create!(visitor: visitor)

    assert_difference -> { VisitorNotificationRecord.count }, -1 do
      assert_difference -> { VisitorAccount.count }, -1 do
        RetentionCrossDatabaseChildPurge.call(actor: visitor)
      end
    end
  end

  test "purge removes operator notification records for an operator" do
    operator = Operator.create!
    OperatorNotificationRecord.create!(operator: operator)

    assert_difference -> { OperatorNotificationRecord.count }, -1 do
      RetentionCrossDatabaseChildPurge.call(actor: operator)
    end
  end

  # The Entra mapping is withdrawn at offboarding but kept for audit. This is
  # where that retention ends: without it the row outlives the operator forever
  # as a cross-database orphan, and its (tid, oid) stays claimed, so a returning
  # person can never be provisioned onto the same Entra object.
  test "purge removes the operator's Entra identity, whatever state it withdrew in" do
    OperatorEntraIdentityState.ensure_defaults!
    operator = Operator.create!
    OperatorEntraIdentity.create!(
      operator_id: operator.id,
      entra_tenant_id: "11111111-2222-3333-4444-555555555555",
      entra_object_id: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      status_id: OperatorEntraIdentityState::REVOKED,
    )

    assert_difference -> { OperatorEntraIdentity.count }, -1 do
      RetentionCrossDatabaseChildPurge.call(actor: operator)
    end
  end

  test "purge leaves another operator's Entra identity alone" do
    OperatorEntraIdentityState.ensure_defaults!
    purged = Operator.create!
    retained = Operator.create!
    OperatorEntraIdentity.create!(
      operator_id: retained.id,
      entra_tenant_id: "11111111-2222-3333-4444-555555555555",
      entra_object_id: "bbbbbbbb-cccc-dddd-eeee-ffffffffffff",
      status_id: OperatorEntraIdentityState::ACTIVE,
    )

    assert_no_difference -> { OperatorEntraIdentity.count } do
      RetentionCrossDatabaseChildPurge.call(actor: purged)
    end
  end

  test "purge returns the actor unchanged" do
    client = Client.create!

    result = RetentionCrossDatabaseChildPurge.call(actor: client)

    assert_same client, result
  end
end
