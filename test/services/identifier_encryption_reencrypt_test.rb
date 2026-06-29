# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class IdentifierEncryptionReencryptTest < ActiveSupport::TestCase
  setup do
    @user = clients(:one)
    @staff = operators(:one)
    @visitor = create_verified_visitor_with_email(
      email_address: "reencrypt-visitor-#{SecureRandom.hex(4)}@example.com",
    )
  end

  test "rewrites encrypted identifier columns across user staff and visitor records" do
    user_email = ClientEmail.create!(
      user: @user,
      address: "reencrypt-user-email-#{SecureRandom.hex(4)}@example.com",
      confirm_policy: true,
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    user_telephone = ClientTelephone.create!(
      user: @user,
      raw_number: "+1 (555) #{rand(100..999)}-#{rand(1000..9999)}",
      confirm_policy: true,
      confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )
    staff_email = OperatorEmail.create!(
      staff: @staff,
      raw_address: "reencrypt-staff-email-#{SecureRandom.hex(4)}@example.com",
      confirm_policy: true,
    )
    staff_telephone = OperatorTelephone.create!(
      staff: @staff,
      raw_number: "+1 (555) #{rand(100..999)}-#{rand(1000..9999)}",
      confirm_policy: true,
      confirm_using_mfa: true,
    )
    visitor_email = @visitor.visitor_emails.last
    visitor_telephone = VisitorTelephone.create!(
      visitor: @visitor,
      raw_number: "+1 (555) #{rand(100..999)}-#{rand(1000..9999)}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
      otp_counter: "0",
      otp_private_key: "secret_credential",
    )

    before_ciphertexts = {
      user_email: ciphertext_for(user_email, :address),
      user_telephone: ciphertext_for(user_telephone, :number),
      staff_email: ciphertext_for(staff_email, :address),
      staff_telephone: ciphertext_for(staff_telephone, :number),
      visitor_email: ciphertext_for(visitor_email, :address),
      visitor_telephone: ciphertext_for(visitor_telephone, :number),
    }

    result = IdentifierEncryptionReencrypt.new.call

    assert_operator result.user_emails_reencrypted, :>=, 1
    assert_operator result.user_telephones_reencrypted, :>=, 1
    assert_operator result.staff_emails_reencrypted, :>=, 1
    assert_operator result.staff_telephones_reencrypted, :>=, 1
    assert_operator result.visitor_emails_reencrypted, :>=, 1
    assert_operator result.visitor_telephones_reencrypted, :>=, 1

    after_ciphertexts = {
      user_email: ciphertext_for(user_email.reload, :address),
      user_telephone: ciphertext_for(user_telephone.reload, :number),
      staff_email: ciphertext_for(staff_email.reload, :address),
      staff_telephone: ciphertext_for(staff_telephone.reload, :number),
      visitor_email: ciphertext_for(visitor_email.reload, :address),
      visitor_telephone: ciphertext_for(visitor_telephone.reload, :number),
    }

    before_ciphertexts.each_key do |key|
      assert_not_equal before_ciphertexts[key], after_ciphertexts[key]
    end
  end

  private

  def ciphertext_for(record, column)
    raw = record.class.connection.execute(
      "SELECT #{column} FROM #{record.class.table_name} WHERE id = #{record.id}",
    ).first

    raw[column.to_s]
  end
end
