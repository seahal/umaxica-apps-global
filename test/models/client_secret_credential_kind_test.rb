# typed: false
# == Schema Information
#
# Table name: client_secret_credential_kinds
# Database name: app_principal
#
#  id :bigint           not null, primary key
#

# frozen_string_literal: true

require "test_helper"

class ClientSecretCredentialKindTest < ActiveSupport::TestCase
  test "valid kind" do
    kind = ClientSecretCredentialKind.new(id: 99)

    assert_predicate kind, :valid?
    assert kind.save
    assert_equal 99, kind.id
  end

  test "validates uniqueness of id" do
    ClientSecretCredentialKind.create!(id: 99)
    duplicate = ClientSecretCredentialKind.new(id: 99)

    assert_predicate duplicate, :invalid?
    assert_predicate duplicate.errors[:id], :any?
  end

  test "constants are defined" do
    assert_equal 1, ClientSecretCredentialKind::LOGIN
    assert_equal 2, ClientSecretCredentialKind::TOTP
    assert_equal 3, ClientSecretCredentialKind::RECOVERY
    assert_equal 4, ClientSecretCredentialKind::API
    assert_equal [1, 2, 3, 4], ClientSecretCredentialKind::ALL
  end

  test "validates id is non-negative" do
    record = ClientSecretCredentialKind.new(id: -1)

    assert_predicate record, :invalid?
    assert record.errors.of_kind?(:id, :greater_than_or_equal_to)
  end

  test "validates id is an integer" do
    record = ClientSecretCredentialKind.new(id: 1.5)

    assert_predicate record, :invalid?
  end
end
