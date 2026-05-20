# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_visibilities
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientVisibilityTest < ActiveSupport::TestCase
  fixtures :client_visibilities, :clients

  test "has correct constants" do
    assert_equal 0, ClientVisibility::NOTHING
    assert_equal 1, ClientVisibility::USER
    assert_equal 2, ClientVisibility::STAFF
    assert_equal 3, ClientVisibility::BOTH
  end

  test "can load nothing status from db" do
    status = ClientVisibility.find(ClientVisibility::NOTHING)

    assert_equal 0, status.id
  end

  test "has expected fixed ids" do
    assert ClientVisibility.exists?(id: ClientVisibility::NOTHING)
    assert ClientVisibility.exists?(id: ClientVisibility::USER)
    assert ClientVisibility.exists?(id: ClientVisibility::STAFF)
    assert ClientVisibility.exists?(id: ClientVisibility::BOTH)
  end

  test "has many clients association" do
    assoc = ClientVisibility.reflect_on_association(:clients)

    assert_not_nil assoc
    assert_equal :has_many, assoc.macro
  end

  test "ensure_defaults! does nothing when defaults exist" do
    assert_no_difference "ClientVisibility.count" do
      ClientVisibility.ensure_defaults!
    end
  end
end
