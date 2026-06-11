# typed: false
# frozen_string_literal: true

require "test_helper"

class SignAppUpTelephoneRegistrationFinalizerTest < ActiveSupport::TestCase
  fixtures :client_statuses,
           :client_visibilities,
           :client_mfa_levels,
           :client_mfa_statuses,
           :client_telephone_statuses,
           :client_passkey_statuses,
           :client_chronicle_events,
           :client_chronicle_levels

  test "finalizes a pending telephone sign-up after passkey setup" do
    user = Client.create!(
      public_id: "c_#{SecureRandom.hex(8)}",
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
      visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
    telephone = ClientTelephone.create!(
      user: user,
      raw_number: "+12345678901",
      confirm_policy: "1",
      confirm_using_mfa: "1",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    telephone.store_otp("secret_credential", 123, 5.minutes.from_now.to_i)
    ClientPasskey.create!(
      user: user,
      webauthn_id: SecureRandom.uuid,
      public_key: "public-key",
      description: "Primary passkey",
      sign_count: 0,
    )

    assert_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::SIGNED_UP_WITH_TELEPHONE).count }, 1 do
      result = SignAppUpTelephoneRegistrationFinalizer.call(telephone: telephone)

      assert_equal user, result.user
    end

    activity = ClientChronicle.order(:created_at).last

    assert_equal ClientChronicleEvent::SIGNED_UP_WITH_TELEPHONE, activity.event_id
    assert_equal user, activity.actor
    assert_equal user.id.to_s, activity.subject_id
    assert_equal "Client", activity.subject_type
    assert_equal ClientTelephoneStatus::VERIFIED_WITH_SIGN_UP, telephone.reload.user_telephone_status_id
    assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, user.reload.status_id
    assert_equal "0", telephone.otp_counter
    assert_equal 0, telephone.otp_attempts_count
    assert_not_predicate telephone, :otp_active?
  end

  test "raises when the required passkey is missing and rolls back the registration" do
    user = Client.create!(
      public_id: "c_#{SecureRandom.hex(8)}",
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
      visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
    telephone = ClientTelephone.create!(
      user: user,
      raw_number: "+12345678902",
      confirm_policy: "1",
      confirm_using_mfa: "1",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    telephone.store_otp("secret_credential", 456, 5.minutes.from_now.to_i)

    assert_no_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::SIGNED_UP_WITH_TELEPHONE).count } do
      assert_raises(SignAppUpTelephoneRegistrationFinalizer::PasskeyMissingError) do
        SignAppUpTelephoneRegistrationFinalizer.call(telephone: telephone)
      end
    end

    assert_equal ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, telephone.reload.user_telephone_status_id
    assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, user.reload.status_id
    assert_equal "456", telephone.otp_counter
    assert_equal 0, telephone.otp_attempts_count
    assert_predicate telephone, :otp_active?
  end
end
