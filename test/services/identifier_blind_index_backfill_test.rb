# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentifierBlindIndexBackfillTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @staff = staffs(:one)
  end

  test "backfills missing digests without saving the records" do
    user_email = UserEmail.create!(
      raw_address: "backfill-user-email@example.com",
      confirm_policy: true,
      user: @user,
    )
    user_telephone = UserTelephone.create!(
      raw_number: "+1 (555) 222-3333",
      confirm_policy: true,
      confirm_using_mfa: true,
      user: @user,
    )
    staff_email = StaffEmail.create!(
      raw_address: "backfill-staff-email@example.com",
      confirm_policy: true,
      staff: @staff,
    )
    staff_telephone = StaffTelephone.create!(
      raw_number: "+1 (555) 444-5555",
      confirm_policy: true,
      confirm_using_mfa: true,
      staff: @staff,
    )

    user_email.update_columns(address_bidx: nil, address_digest: nil)
    user_telephone.update_columns(number_bidx: nil, number_digest: nil)
    staff_email.update_columns(address_bidx: nil, address_digest: nil)
    staff_telephone.update_columns(number_bidx: nil, number_digest: nil)

    result = IdentifierBlindIndexBackfill.new.call

    assert_equal IdentifierBlindIndex.bidx_for_email("backfill-user-email@example.com"),
                 user_email.reload.address_digest
    assert_equal IdentifierBlindIndex.bidx_for_telephone("+15552223333"), user_telephone.reload.number_digest
    assert_equal IdentifierBlindIndex.bidx_for_email("backfill-staff-email@example.com"),
                 staff_email.reload.address_digest
    assert_equal IdentifierBlindIndex.bidx_for_telephone("+15554445555"), staff_telephone.reload.number_digest

    assert_operator result.user_emails_updated, :>=, 1
    assert_operator result.user_telephones_updated, :>=, 1
    assert_operator result.staff_emails_updated, :>=, 1
    assert_operator result.staff_telephones_updated, :>=, 1
  end

  test "is idempotent when digests are already current" do
    staff_email = StaffEmail.create!(
      raw_address: "idempotent-staff@example.com",
      confirm_policy: true,
      staff: @staff,
    )

    IdentifierBlindIndexBackfill.new.call

    assert_equal IdentifierBlindIndex.bidx_for_email("idempotent-staff@example.com"), staff_email.reload.address_digest
  end
end
