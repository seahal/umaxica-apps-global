# typed: false
# frozen_string_literal: true

require "test_helper"

class UserCoverageTest < ActiveSupport::TestCase
  setup do
    UserStatus.find_or_create_by!(id: 1)
    UserVisibility.find_or_create_by!(id: 1)
    @user = User.create!(status_id: 1, visibility_id: 1)
    UserEmailStatus.find_or_create_by!(id: UserEmailStatus::VERIFIED)
    UserTelephoneStatus.find_or_create_by!(id: UserTelephoneStatus::VERIFIED)
    UserSocialGoogleStatus.find_or_create_by!(id: UserSocialGoogleStatus::ACTIVE)
    UserSocialAppleStatus.find_or_create_by!(id: UserSocialAppleStatus::ACTIVE)
    UserOneTimePasswordStatus.find_or_create_by!(id: UserOneTimePasswordStatus::ACTIVE)
  end

  test "totp_enabled?" do
    assert_not @user.totp_enabled?
    UserOneTimePassword.create!(user: @user, user_identity_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE)

    assert_predicate @user, :totp_enabled?

    @user.user_one_time_passwords.load

    assert_predicate @user, :totp_enabled?
  end

  test "staff? and user? predicates" do
    assert_not @user.staff?
    assert_predicate @user, :user?
  end

  test "user_social_googles shim" do
    assert_empty @user.user_social_googles
    google = UserSocialGoogle.create!(
      user: @user, uid: "u", provider: "google",
      status_id: UserSocialGoogleStatus::ACTIVE, token: "t", expires_at: 0,
    )

    assert_equal [google], @user.user_social_googles
  end

  test "verified_email? and verified_telephone?" do
    assert_not @user.verified_email?
    UserEmail.create!(user: @user, address: "v@example.com", user_email_status_id: UserEmailStatus::VERIFIED)

    assert_predicate @user, :verified_email?

    assert_not @user.verified_telephone?
    UserTelephone.create!(user: @user, number: "+819012345678", user_identity_telephone_status_id: UserTelephoneStatus::VERIFIED)

    assert_predicate @user, :verified_telephone?
  end

  test "withdrawal and deactivation predicates" do
    assert_not @user.withdrawal_started?
    assert_not @user.deactivated?
    assert_not @user.withdrawal_in_progress?

    @user.update!(withdrawal_started_at: Time.current)

    assert_predicate @user, :withdrawal_started?
    assert_predicate @user, :withdrawal_in_progress?

    @user.update!(deactivated_at: Time.current)

    assert_predicate @user, :deactivated?
    assert_predicate @user, :withdrawal_in_progress?
  end

  test "active_social_provider?" do
    assert_not @user.active_social_provider?("google")
    UserSocialGoogle.create!(
      user: @user, uid: "g", provider: "google", status_id: UserSocialGoogleStatus::ACTIVE,
      token: "t", expires_at: 0,
    )

    assert @user.active_social_provider?("google")

    assert_not @user.active_social_provider?("apple")
    UserSocialApple.create!(
      user: @user, uid: "a", provider: "apple", status_id: UserSocialAppleStatus::ACTIVE,
      token: "t", expires_at: 0,
    )

    assert @user.active_social_provider?("apple")

    assert_not @user.active_social_provider?("unknown")
  end

  test "UserEmail verification tokens" do
    email = UserEmail.create!(user: @user, address: "token@example.com", user_email_status_id: 1)
    raw = email.generate_verification_token

    assert_not_nil raw
    assert email.verify_verification_token(raw)
    assert_not email.verify_verification_token("wrong")
  end
end
