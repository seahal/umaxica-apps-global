# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_totp_credential_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientTotpCredentialStatusTest < ActiveSupport::TestCase
  test "status constants are defined" do
    assert_equal 1, ClientTotpCredentialStatus::ACTIVE
    assert_equal 2, ClientTotpCredentialStatus::INACTIVE
    assert_equal 3, ClientTotpCredentialStatus::REVOKED
    assert_equal 4, ClientTotpCredentialStatus::DELETED
    assert_equal 5, ClientTotpCredentialStatus::NOTHING
  end

  test "status ids are integers" do
    assert_kind_of Integer, ClientTotpCredentialStatus::ACTIVE
    assert_kind_of Integer, ClientTotpCredentialStatus::INACTIVE
    assert_kind_of Integer, ClientTotpCredentialStatus::REVOKED
    assert_kind_of Integer, ClientTotpCredentialStatus::DELETED
    assert_kind_of Integer, ClientTotpCredentialStatus::NOTHING
  end
end
