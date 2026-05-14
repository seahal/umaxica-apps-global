# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_accounts
# Database name: operator
#
#  id            :bigint           not null, primary key
#  lock_version  :integer          default(0), not null
#  moniker       :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  department_id :bigint
#  public_id     :string           not null
#  staff_id      :bigint           not null
#  status_id     :bigint           default(2), not null
#
# Indexes
#
#  index_operator_accounts_on_department_id  (department_id)
#  index_operator_accounts_on_public_id      (public_id) UNIQUE
#  index_operator_accounts_on_staff_id       (staff_id)
#  index_operator_accounts_on_status_id      (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (department_id => departments.id) ON DELETE => nullify
#  fk_rails_...  (staff_id => operators.id)
#  fk_rails_...  (status_id => operator_statuses.id)
#
require "test_helper"

class OperatorAccountTest < ActiveSupport::TestCase
  fixtures :staffs, :staff_statuses, :operator_statuses

  test "uses conventional table name" do
    assert_equal "operator_accounts", OperatorAccount.table_name
  end

  test "can create operator account with operator actor" do
    operator_actor = Operator.create!(public_id: "ABCDEFGH2345WXYZ")
    account = OperatorAccount.create!(operator: operator_actor)

    assert_predicate account, :persisted?
    assert_equal operator_actor, account.operator
  end

  test "operator actor has many operator accounts" do
    operator_actor = Operator.create!(public_id: "ABCDEFGH2345WXY2")
    account = OperatorAccount.create!(operator: operator_actor)

    assert_includes operator_actor.operator_accounts, account
  end

  test "belongs to operator actor" do
    operator_actor = Operator.create!(public_id: "ABCDEFGH2345WXY3")
    account = OperatorAccount.create!(operator: operator_actor)

    assert_equal operator_actor, account.operator
  end
end
