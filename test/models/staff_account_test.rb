# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_accounts
# Database name: personnel
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  staff_id   :bigint           not null
#
# Indexes
#
#  index_staff_accounts_on_public_id  (public_id) UNIQUE
#  index_staff_accounts_on_staff_id   (staff_id) UNIQUE
#
require "test_helper"

class OperatorPersonnelAccountTest < ActiveSupport::TestCase
  test "creates one account for a staff" do
    account = OperatorPersonnelAccount.create!(staff: staffs(:one))

    assert_predicate account.public_id, :present?
    assert_equal PersonnelRecord.connection_db_config.name, account.class.connection_db_config.name
    assert_equal account, staffs(:one).reload.staff_account
  end

  test "requires a staff" do
    account = OperatorPersonnelAccount.new

    assert_not account.valid?
    assert account.errors.of_kind?(:staff, :blank)
  end

  test "allows only one account per staff" do
    OperatorPersonnelAccount.create!(staff: staffs(:two))

    duplicate = OperatorPersonnelAccount.new(staff: staffs(:two))

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:staff_id, :taken)
  end
end
