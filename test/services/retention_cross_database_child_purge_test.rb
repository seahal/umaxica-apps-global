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

  test "purge returns the actor unchanged" do
    client = Client.create!

    result = RetentionCrossDatabaseChildPurge.call(actor: client)

    assert_same client, result
  end
end
