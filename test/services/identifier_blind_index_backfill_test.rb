# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentifierBlindIndexBackfillTest < ActiveSupport::TestCase
  setup do
    @user = clients(:one)
    @staff = operators(:one)
    @visitor = create_verified_visitor_with_email(
      email_address: "backfill-seed-visitor-#{SecureRandom.hex(4)}@example.com",
    )
  end

  test "backfills missing digests without saving the records" do
    user_email = ClientEmail.create!(
      raw_address: "backfill-user-email@example.com",
      confirm_policy: true,
      user: @user,
    )
    user_telephone = ClientTelephone.create!(
      raw_number: "+1 (555) 222-3333",
      confirm_policy: true,
      confirm_using_mfa: true,
      user: @user,
    )
    staff_email = OperatorEmail.create!(
      raw_address: "backfill-staff-email@example.com",
      confirm_policy: true,
      staff: @staff,
    )
    staff_telephone = OperatorTelephone.create!(
      raw_number: "+1 (555) 444-5555",
      confirm_policy: true,
      confirm_using_mfa: true,
      staff: @staff,
    )
    visitor_email = VisitorEmail.create!(
      raw_address: "backfill-visitor-email@example.com",
      confirm_policy: true,
      visitor: @visitor,
    )
    visitor_telephone = VisitorTelephone.create!(
      raw_number: "+1 (555) 666-7777",
      visitor: @visitor,
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED,
      otp_counter: "0",
      otp_private_key: "secret",
    )

    user_email.update_columns(columns_to_clear(ClientEmail, address_bidx: nil, address_digest: nil))
    user_telephone.update_columns(columns_to_clear(ClientTelephone, number_bidx: nil, number_digest: nil))
    staff_email.update_columns(columns_to_clear(OperatorEmail, address_bidx: nil, address_digest: nil))
    staff_telephone.update_columns(columns_to_clear(OperatorTelephone, number_bidx: nil, number_digest: nil))
    visitor_email.update_columns(columns_to_clear(VisitorEmail, address_bidx: nil, address_digest: nil))
    visitor_telephone.update_columns(columns_to_clear(VisitorTelephone, number_bidx: nil, number_digest: nil))

    result = IdentifierBlindIndexBackfill.new.call

    assert_equal IdentifierBlindIndex.bidx_for_email("backfill-user-email@example.com"),
                 user_email.reload.address_digest
    assert_equal IdentifierBlindIndex.bidx_for_telephone("+15552223333"), user_telephone.reload.number_digest
    assert_equal IdentifierBlindIndex.bidx_for_email("backfill-staff-email@example.com"),
                 staff_email.reload.address_digest
    assert_equal IdentifierBlindIndex.bidx_for_telephone("+15554445555"), staff_telephone.reload.number_digest
    assert_equal IdentifierBlindIndex.bidx_for_email("backfill-visitor-email@example.com"),
                 visitor_email.reload.address_digest
    assert_equal IdentifierBlindIndex.bidx_for_telephone("+15556667777"), visitor_telephone.reload.number_digest

    assert_operator result.user_emails_updated, :>=, 1
    assert_operator result.user_telephones_updated, :>=, 1
    assert_operator result.staff_emails_updated, :>=, 1
    assert_operator result.staff_telephones_updated, :>=, 1
    assert_operator result.visitor_emails_updated, :>=, 1
    assert_operator result.visitor_telephones_updated, :>=, 1
  end

  test "is idempotent when digests are already current" do
    staff_email = OperatorEmail.create!(
      raw_address: "idempotent-staff@example.com",
      confirm_policy: true,
      staff: @staff,
    )

    IdentifierBlindIndexBackfill.new.call

    assert_equal IdentifierBlindIndex.bidx_for_email("idempotent-staff@example.com"), staff_email.reload.address_digest
  end

  private

  def columns_to_clear(model, columns)
    columns.slice(*model.column_names.map(&:to_sym))
  end
end
