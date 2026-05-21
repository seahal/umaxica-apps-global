# typed: false
# == Schema Information
#
# Table name: operator_secret_kinds
# Database name: org_principal
#
#  id :bigint           not null, primary key
#

# frozen_string_literal: true

require "test_helper"

class OperatorSecretKindTest < ActiveSupport::TestCase
  test "valid kind" do
    kind = OperatorSecretKind.new(id: 99)

    assert_predicate kind, :valid?
    assert kind.save
    assert_equal 99, kind.id
  end

  test "validates uniqueness of id" do
    OperatorSecretKind.create!(id: 77)
    duplicate = OperatorSecretKind.new(id: 77)

    assert_predicate duplicate, :invalid?
    assert_predicate duplicate.errors[:id], :any?
  end

  test "constants are defined" do
    assert_equal 2, OperatorSecretKind::LOGIN
    assert_equal [2], OperatorSecretKind::ALL
  end
end
