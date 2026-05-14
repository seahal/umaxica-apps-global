# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_accounts
# Database name: visitor
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  visitor_id :bigint           not null
#
# Indexes
#
#  index_client_accounts_on_public_id   (public_id) UNIQUE
#  index_client_accounts_on_visitor_id  (visitor_id) UNIQUE
#
require "test_helper"

class VisitorClientAccountTest < ActiveSupport::TestCase
  setup do
    VisitorStatus.ensure_defaults!
    VisitorVisibility.ensure_defaults!
  end

  test "creates one visitor scoped client account for a visitor" do
    visitor = Visitor.create!
    account = VisitorClientAccount.create!(visitor: visitor)

    assert_predicate account.public_id, :present?
    assert_equal VisitorRecord.connection_db_config.name, account.class.connection_db_config.name
    assert_equal account, visitor.reload.client_account
  end

  test "requires a visitor" do
    account = VisitorClientAccount.new

    assert_not account.valid?
    assert account.errors.of_kind?(:visitor, :blank)
  end

  test "allows only one account per visitor" do
    visitor = Visitor.create!
    VisitorClientAccount.create!(visitor: visitor)

    duplicate = VisitorClientAccount.new(visitor: visitor)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:visitor_id, :taken)
  end

  test "requires unique generated public id" do
    account = VisitorClientAccount.create!(visitor: Visitor.create!)

    duplicate = VisitorClientAccount.new(visitor: Visitor.create!, public_id: account.public_id)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:public_id, :taken)
  end
end
