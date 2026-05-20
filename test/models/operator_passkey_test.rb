# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_passkeys
# Database name: org_principal
#
#  id           :bigint           not null, primary key
#  last_used_at :datetime
#  name         :string           not null
#  public_key   :text             not null
#  sign_count   :integer          not null
#  transports   :string
#  user_handle  :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  external_id  :string           not null
#  staff_id     :bigint           not null
#  status_id    :bigint           default(1), not null
#  webauthn_id  :string           default(""), not null
#
# Indexes
#
#  index_staff_passkeys_on_external_id  (external_id)
#  index_staff_passkeys_on_staff_id     (staff_id)
#  index_staff_passkeys_on_status_id    (status_id)
#  index_staff_passkeys_on_webauthn_id  (webauthn_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#  fk_rails_...  (status_id => staff_passkey_statuses.id)
#

require "test_helper"

class OperatorPasskeyTest < ActiveSupport::TestCase
  test "should create passkey with valid attributes" do
    passkey = OperatorPasskey.new(
      staff: Operator.find_by!(public_id: "BCDE2345FGHJ67KM"),
      name: "Staff Passkey",
      public_key: "test_staff_public_key",
      sign_count: 1,
      external_id: SecureRandom.uuid,
      webauthn_id: SecureRandom.hex(32),
    )

    assert_equal "Staff Passkey", passkey.name
    assert_equal "test_staff_public_key", passkey.public_key
    assert_equal 1, passkey.sign_count
  end

  test "defaults status_id to active" do
    passkey = OperatorPasskey.new(
      staff: Operator.find_by!(public_id: "BCDE2345FGHJ67KM"),
      name: "Staff Passkey",
      public_key: "test_staff_public_key",
      sign_count: 1,
      external_id: SecureRandom.uuid,
      webauthn_id: SecureRandom.hex(32),
    )

    assert_equal OperatorPasskeyStatus::ACTIVE, passkey.status_id
  end

  test "status association uses status_id" do
    status = OperatorPasskeyStatus.find(OperatorPasskeyStatus::ACTIVE)
    passkey = OperatorPasskey.create!(
      staff: Operator.find_by!(public_id: "BCDE2345FGHJ67KM"),
      name: "Staff Passkey",
      public_key: "test_staff_public_key",
      sign_count: 1,
      external_id: SecureRandom.uuid,
      webauthn_id: SecureRandom.hex(32),
      status: status,
    )

    assert_equal status, passkey.reload.status
    assert_equal status.id, passkey.status_id
  end

  test "should belong to staff" do
    assert_respond_to OperatorPasskey.new, :staff
  end

  test "should have name field" do
    passkey = OperatorPasskey.new(name: "Example Name")

    assert_equal "Example Name", passkey.name
  end

  test "should have public_key field" do
    passkey = OperatorPasskey.new(public_key: "staff_key")

    assert_equal "staff_key", passkey.public_key
  end

  test "should inherit from OrgPrincipalRecord" do
    assert_operator OperatorPasskey, :<, OrgPrincipalRecord
  end

  test "should have required database columns" do
    required_columns = %w(name public_key sign_count external_id staff_id webauthn_id)

    required_columns.each do |column|
      assert_includes OperatorPasskey.column_names, column
    end
  end

  test "enforces maximum passkeys per staff" do
    staff = Operator.find_by!(public_id: "BCDE2345FGHJ67KM")
    relation_stub = Struct.new(:count).new(OperatorPasskey::MAX_PASSKEYS_PER_STAFF)

    OperatorPasskey.stub(:where, relation_stub) do
      extra_passkey = OperatorPasskey.new(
        staff: staff,
        name: "Overflow Staff Key",
        public_key: "overflow-key",
        sign_count: 0,
        external_id: SecureRandom.uuid,
        webauthn_id: SecureRandom.hex(32),
      )

      assert_not extra_passkey.valid?
      assert_includes extra_passkey.errors[:base],
                      "exceeds maximum passkeys per staff (#{OperatorPasskey::MAX_PASSKEYS_PER_STAFF})"
    end
  end
end
