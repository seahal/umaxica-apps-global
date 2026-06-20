# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentifierEncryptionRotationDrillTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @service_host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @staff_host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @corporate_host = ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")

    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }

    VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED_WITH_SIGN_UP)

    @user = clients(:one)
    @staff = operators(:one)
    @staff_token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    satisfy_staff_verification(@staff_token)
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "rotation drill preserves existing records and keeps app org and com flows working" do
    old_primary_key = SecureRandom.hex(32)
    new_primary_key = SecureRandom.hex(32)

    app_email_address = "rotation-app-email-#{SecureRandom.hex(4)}@example.com"
    app_telephone_number = "+1555#{SecureRandom.random_number(10_000_000).to_s.rjust(7, "0")}"
    staff_email_address = "rotation-org-email-#{SecureRandom.hex(4)}@example.com"
    visitor_email_address = "rotation-com-email-#{SecureRandom.hex(4)}@example.com"

    old_provider = encryption_key_provider(old_primary_key)
    rotation_provider = encryption_key_provider(new_primary_key, old_primary_key)
    ActiveRecord::Encryption.with_encryption_context(key_provider: old_provider) do
      old_app_email = ClientEmail.create!(
        user: @user,
        raw_address: app_email_address,
        confirm_policy: true,
        user_email_status_id: ClientEmailStatus::VERIFIED,
      )
      old_app_telephone = ClientTelephone.create!(
        user: @user,
        raw_number: app_telephone_number,
        confirm_policy: true,
        confirm_using_mfa: true,
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
      )
      old_staff_email = OperatorEmail.create!(
        staff: @staff,
        raw_address: staff_email_address,
        confirm_policy: true,
        staff_email_status_id: OperatorEmailStatus::VERIFIED,
      )
      visitor = Visitor.create!(
        status_id: VisitorStatus::ACTIVE,
        visibility_id: VisitorVisibility::VISITOR,
      )
      old_visitor_email = VisitorEmail.create!(
        visitor: visitor,
        address: visitor_email_address,
        confirm_policy: true,
        visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      )

      ActiveRecord::Encryption.with_encryption_context(key_provider: rotation_provider) do
        reencrypt_result = IdentifierEncryptionReencrypt.new.call

        assert_operator reencrypt_result.user_emails_reencrypted, :>=, 1
        assert_operator reencrypt_result.user_telephones_reencrypted, :>=, 1
        assert_operator reencrypt_result.staff_emails_reencrypted, :>=, 1
        assert_operator reencrypt_result.visitor_emails_reencrypted, :>=, 1

        assert_equal app_email_address, old_app_email.reload.address
        assert_equal app_telephone_number, old_app_telephone.reload.number
        assert_equal staff_email_address, old_staff_email.reload.address
        assert_equal visitor_email_address, old_visitor_email.reload.address

        assert_app_sign_in_email_flow(app_email_address)
      end
    end
  end

  private

  def assert_app_sign_in_email_flow(address)
    post(
      sign_app_sign_in_email_url(ri: "jp"),
      params: {
        user_email: { address: address },
        "cf-turnstile-response": "test",
      },
      headers: { "Host" => @service_host },
    )

    assert_response :found

    email = ClientEmail.find_by!(address_digest: IdentifierBlindIndex.bidx_for_email(address))
    otp_data = email.get_otp
    code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    patch(
      sign_app_sign_in_email_url(ri: "jp"),
      params: { user_email: { pass_code: code } },
      headers: { "Host" => @service_host },
    )

    assert_response :found
    assert_redirected_to sign_app_sign_in_check_path(ri: "jp")
  end

  def encryption_key_provider(*passwords)
    ActiveRecord::Encryption::KeyProvider.new(
      passwords.map { |password| ActiveRecord::Encryption::Key.derive_from(password) },
    )
  end
end
