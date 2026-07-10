# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_secret_credential_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientSecretCredentialStatusTest < ActiveSupport::TestCase
  test "status constants are defined" do
    assert_equal 1, ClientSecretCredentialStatus::ACTIVE
    assert_equal 2, ClientSecretCredentialStatus::EXPIRED
    assert_equal 3, ClientSecretCredentialStatus::REVOKED
    assert_equal 4, ClientSecretCredentialStatus::USED
    assert_equal 5, ClientSecretCredentialStatus::DELETED
    assert_equal 6, ClientSecretCredentialStatus::NOTHING
  end

  test "status ids are integers" do
    assert_kind_of Integer, ClientSecretCredentialStatus::ACTIVE
    assert_kind_of Integer, ClientSecretCredentialStatus::EXPIRED
    assert_kind_of Integer, ClientSecretCredentialStatus::REVOKED
    assert_kind_of Integer, ClientSecretCredentialStatus::USED
    assert_kind_of Integer, ClientSecretCredentialStatus::DELETED
    assert_kind_of Integer, ClientSecretCredentialStatus::NOTHING
  end
end
