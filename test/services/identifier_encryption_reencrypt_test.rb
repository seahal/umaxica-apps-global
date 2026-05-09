# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentifierEncryptionReencryptTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @staff = staffs(:one)
    @customer = create_verified_customer_with_email(
      email_address: "reencrypt-customer-#{SecureRandom.hex(4)}@example.com",
    )
  end

  test "rewrites encrypted identifier columns across user staff and customer records" do
    user_email = UserEmail.create!(
      user: @user,
      address: "reencrypt-user-email-#{SecureRandom.hex(4)}@example.com",
      confirm_policy: true,
      user_email_status_id: UserEmailStatus::VERIFIED,
    )
    user_telephone = UserTelephone.create!(
      user: @user,
      raw_number: "+1 (555) #{rand(100..999)}-#{rand(1000..9999)}",
      confirm_policy: true,
      confirm_using_mfa: true,
      user_telephone_status_id: UserTelephoneStatus::VERIFIED,
    )
    staff_email = StaffEmail.create!(
      staff: @staff,
      raw_address: "reencrypt-staff-email-#{SecureRandom.hex(4)}@example.com",
      confirm_policy: true,
    )
    staff_telephone = StaffTelephone.create!(
      staff: @staff,
      raw_number: "+1 (555) #{rand(100..999)}-#{rand(1000..9999)}",
      confirm_policy: true,
      confirm_using_mfa: true,
    )
    customer_email = @customer.customer_emails.last
    customer_telephone = CustomerTelephone.create!(
      customer: @customer,
      raw_number: "+1 (555) #{rand(100..999)}-#{rand(1000..9999)}",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
      otp_counter: "0",
      otp_private_key: "secret",
    )

    before_ciphertexts = {
      user_email: ciphertext_for(user_email, :address),
      user_telephone: ciphertext_for(user_telephone, :number),
      staff_email: ciphertext_for(staff_email, :address),
      staff_telephone: ciphertext_for(staff_telephone, :number),
      customer_email: ciphertext_for(customer_email, :address),
      customer_telephone: ciphertext_for(customer_telephone, :number),
    }

    result = IdentifierEncryptionReencrypt.new.call

    assert_operator result.user_emails_reencrypted, :>=, 1
    assert_operator result.user_telephones_reencrypted, :>=, 1
    assert_operator result.staff_emails_reencrypted, :>=, 1
    assert_operator result.staff_telephones_reencrypted, :>=, 1
    assert_operator result.customer_emails_reencrypted, :>=, 1
    assert_operator result.customer_telephones_reencrypted, :>=, 1

    after_ciphertexts = {
      user_email: ciphertext_for(user_email.reload, :address),
      user_telephone: ciphertext_for(user_telephone.reload, :number),
      staff_email: ciphertext_for(staff_email.reload, :address),
      staff_telephone: ciphertext_for(staff_telephone.reload, :number),
      customer_email: ciphertext_for(customer_email.reload, :address),
      customer_telephone: ciphertext_for(customer_telephone.reload, :number),
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
