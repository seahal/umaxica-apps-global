# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentifierHmacEmergencyRotationTest < ActiveSupport::TestCase
  setup do
    @user = clients(:one)
    @staff = operators(:one)
    @visitor = create_verified_visitor_with_email(
      email_address: "hmac-rotation-seed-visitor-#{SecureRandom.hex(4)}@example.com",
    )
  end

  test "overwrites stale identifier digests across user staff and visitor records" do
    user_email = ClientEmail.create!(
      user: @user,
      raw_address: "hmac-rotation-user-#{SecureRandom.hex(4)}@example.com",
      confirm_policy: true,
    )
    user_telephone = ClientTelephone.create!(
      user: @user,
      raw_number: "+1 (555) #{rand(100..999)}-#{rand(1000..9999)}",
      confirm_policy: true,
      confirm_using_mfa: true,
    )
    staff_email = OperatorEmail.create!(
      staff: @staff,
      raw_address: "hmac-rotation-staff-#{SecureRandom.hex(4)}@example.com",
      confirm_policy: true,
    )
    staff_telephone = OperatorTelephone.create!(
      staff: @staff,
      raw_number: "+1 (555) #{rand(100..999)}-#{rand(1000..9999)}",
      confirm_policy: true,
      confirm_using_mfa: true,
    )
    visitor_email = VisitorEmail.create!(
      visitor: @visitor,
      raw_address: "hmac-rotation-visitor-#{SecureRandom.hex(4)}@example.com",
      confirm_policy: true,
    )
    visitor_telephone = VisitorTelephone.create!(
      visitor: @visitor,
      raw_number: "+1 (555) #{rand(100..999)}-#{rand(1000..9999)}",
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED,
      otp_counter: "0",
      otp_private_key: "secret",
    )

    records = [
      [user_email, :address, :address_digest, :bidx_for_email],
      [user_telephone, :number, :number_digest, :bidx_for_telephone],
      [staff_email, :address, :address_digest, :bidx_for_email],
      [staff_telephone, :number, :number_digest, :bidx_for_telephone],
      [visitor_email, :address, :address_digest, :bidx_for_email],
      [visitor_telephone, :number, :number_digest, :bidx_for_telephone],
    ]

    records.each do |record, _identifier_column, digest_column, _digest_method|
      record.update_columns(digest_column => "stale-#{SecureRandom.hex(24)}")
    end

    result = IdentifierHmacEmergencyRotation.new.call

    assert_operator result.user_emails_updated, :>=, 1
    assert_operator result.user_telephones_updated, :>=, 1
    assert_operator result.staff_emails_updated, :>=, 1
    assert_operator result.staff_telephones_updated, :>=, 1
    assert_operator result.visitor_emails_updated, :>=, 1
    assert_operator result.visitor_telephones_updated, :>=, 1
    assert_equal 0, result.records_failed

    records.each do |record, identifier_column, digest_column, digest_method|
      identifier = record.reload.public_send(identifier_column)
      expected = IdentifierBlindIndex.public_send(digest_method, identifier)

      assert_equal expected, record.public_send(digest_column)
    end
  end
end
