# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_accounts
# Database name: resident
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_user_accounts_on_public_id  (public_id) UNIQUE
#  index_user_accounts_on_user_id    (user_id) UNIQUE
#
require "test_helper"

class UserAccountTest < ActiveSupport::TestCase
  test "creates one account for a user" do
    account = UserAccount.create!(user: users(:one))

    assert_predicate account.public_id, :present?
    assert_equal ResidentRecord.connection_db_config.name, account.class.connection_db_config.name
    assert_equal account, users(:one).reload.user_account
  end

  test "requires a user" do
    account = UserAccount.new

    assert_not account.valid?
    assert account.errors.of_kind?(:user, :blank)
  end

  test "allows only one account per user" do
    UserAccount.create!(user: users(:two))

    duplicate = UserAccount.new(user: users(:two))

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:user_id, :taken)
  end
end
