# typed: false
# == Schema Information
#
# Table name: client_secret_kinds
# Database name: app_principal
#
#  id :bigint           not null, primary key
#

# frozen_string_literal: true

require "test_helper"

class ClientSecretKindTest < ActiveSupport::TestCase
  test "valid kind" do
    kind = ClientSecretKind.new(id: 99)

    assert_predicate kind, :valid?
    assert kind.save
    assert_equal 99, kind.id
  end

  test "validates uniqueness of id" do
    ClientSecretKind.create!(id: 99)
    duplicate = ClientSecretKind.new(id: 99)

    assert_predicate duplicate, :invalid?
    assert_predicate duplicate.errors[:id], :any?
  end

  test "constants are defined" do
    assert_equal 1, ClientSecretKind::LOGIN
    assert_equal 2, ClientSecretKind::TOTP
    assert_equal 3, ClientSecretKind::RECOVERY
    assert_equal 4, ClientSecretKind::API
    assert_equal [1, 2, 3, 4], ClientSecretKind::ALL
  end

  test "validates id is non-negative" do
    record = ClientSecretKind.new(id: -1)

    assert_predicate record, :invalid?
    assert_includes record.errors[:id], "は0以上の値にしてください"
  end

  test "validates id is an integer" do
    record = ClientSecretKind.new(id: 1.5)

    assert_predicate record, :invalid?
  end
end
