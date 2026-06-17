# typed: false
# frozen_string_literal: true

require "test_helper"

class RecoveryIdentityRequiredValidatorTest < ActiveSupport::TestCase
  class FakeModelWithConstantMessage
    include ActiveModel::Model

    attr_accessor :owner

    RECOVERY_REQUIRED = "Custom recovery message constant"

    validates_with RecoveryIdentityRequiredValidator, owner: :owner, message: :RECOVERY_REQUIRED
  end

  class FakeModelWithStringMessage
    include ActiveModel::Model

    attr_accessor :owner

    validates_with RecoveryIdentityRequiredValidator, owner: :owner, message: "String message"
  end

  FakeOwnerWithoutRecovery =
    Class.new do
      def has_verified_recovery_identity? = false
    end

  FakeOwnerWithRecovery =
    Class.new do
      def has_verified_recovery_identity? = true
    end

  test "adds error when owner lacks verified recovery identity with symbol message" do
    record = FakeModelWithConstantMessage.new(owner: FakeOwnerWithoutRecovery.new)
    record.validate

    assert_includes record.errors[:base], "Custom recovery message constant"
  end

  test "uses string message directly when message option is not a symbol" do
    record = FakeModelWithStringMessage.new(owner: FakeOwnerWithoutRecovery.new)
    record.validate

    assert_includes record.errors[:base], "String message"
  end

  test "does not add error when owner has verified recovery identity" do
    record = FakeModelWithConstantMessage.new(owner: FakeOwnerWithRecovery.new)
    record.validate

    assert_empty record.errors[:base]
  end

  test "adds error when owner is nil (safe navigation returns nil, not early return)" do
    record = FakeModelWithConstantMessage.new(owner: nil)
    record.validate

    assert_includes record.errors[:base], "Custom recovery message constant"
  end
end
