# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: users
# Database name: principal
#
#  id                    :bigint           not null, primary key
#  deactivated_at        :datetime
#  lapses_at             :datetime         default(Infinity), not null
#  last_reauth_at        :datetime
#  lock_version          :integer          default(0), not null
#  multi_factor_enabled  :boolean          default(FALSE), not null
#  purge_at              :datetime         default(Infinity), not null
#  purged_at             :datetime
#  withdrawal_started_at :datetime
#  withdrawn_at          :datetime         default(Infinity)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  public_id             :string(255)      default(""), not null
#  status_id             :bigint           default(11), not null
#  visibility_id         :bigint           default(2), not null
#
# Indexes
#
#  index_users_on_deactivated_at         (deactivated_at) WHERE (deactivated_at IS NOT NULL)
#  index_users_on_public_id              (public_id) UNIQUE
#  index_users_on_purge_at               (purge_at)
#  index_users_on_purged_at              (purged_at) WHERE (purged_at IS NOT NULL)
#  index_users_on_status_id              (status_id)
#  index_users_on_visibility_id          (visibility_id)
#  index_users_on_withdrawal_started_at  (withdrawal_started_at) WHERE (withdrawal_started_at IS NOT NULL)
#  index_users_on_withdrawn_at           (withdrawn_at) WHERE (withdrawn_at IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => user_statuses.id)
#  fk_rails_...  (visibility_id => user_visibilities.id)
#

require "test_helper"

class UserTest < ActiveSupport::TestCase
  NIL_UUID = "00000000-0000-0000-0000-000000000000"

  def setup
    [0, 1, 2, 3].each { |id| UserVisibility.find_or_create_by!(id: id) }

    @user =
      User.create!(public_id: "u_#{SecureRandom.hex(8)}") do |u|
        u.status_id = UserStatus::NOTHING
      end
  end

  test "should be valid" do
    assert_predicate @user, :valid?
  end

  test "should have timestamps" do
    assert_not_nil @user.created_at
    assert_not_nil @user.updated_at
  end

  test "should have one user_social_apple association" do
    assert_respond_to @user, :user_social_apple
    assert_equal :has_one, @user.class.reflect_on_association(:user_social_apple).macro
  end

  test "should have one user_social_google association" do
    assert_respond_to @user, :user_social_google
    assert_equal :has_one, @user.class.reflect_on_association(:user_social_google).macro
  end

  test "staff? should return false" do
    assert_not @user.staff?
  end

  test "user? should return true" do
    assert_predicate @user, :user?
  end

  test "should set default status before creation" do
    user = User.create!

    assert_equal UserStatus::NOTHING, user.status_id
  end

  test "should default visibility_id to staff (2)" do
    user = User.create!

    assert_equal UserVisibility::STAFF, user.visibility_id
  end

  test "login_allowed? is false for reserved status" do
    @user.update!(status_id: UserStatus::RESERVED)

    assert_not @user.login_allowed?
  end

  test "login_allowed? remains true for nothing status while active" do
    assert_predicate @user, :login_allowed?
  end

  test "visibility association resolves to UserVisibility with id 2 by default" do
    user = User.create!

    assert_equal UserVisibility::STAFF, user.visibility.id
  end

  test "invalid visibility_id is rejected by foreign key" do
    user = User.new(
      public_id: "u_fk_#{SecureRandom.hex(6)}",
      status_id: UserStatus::NOTHING,
      visibility_id: 9_999,
    )
    assert_raises(ActiveRecord::InvalidForeignKey) do
      user.save!(validate: false)
    end
  end

  test "should have many user_emails association" do
    assert_respond_to @user, :user_emails
    assert_equal :has_many, @user.class.reflect_on_association(:user_emails).macro
  end

  test "should have many user_secrets association" do
    assert_respond_to @user, :user_secrets
    assert_equal :has_many, @user.class.reflect_on_association(:user_secrets).macro
  end

  test "should have many user_passkeys association" do
    assert_respond_to @user, :user_passkeys
    assert_equal :has_many, @user.class.reflect_on_association(:user_passkeys).macro
  end

  test "boundary values: public_id must be unique" do
    @user.public_id = "duplicate-id"
    @user.save!

    duplicate_user = User.new(public_id: "duplicate-id")

    assert_not duplicate_user.valid?
    assert_not_empty duplicate_user.errors[:public_id]
  end

  test "boundary values: public_id length" do
    @user.public_id = "a" * 22

    assert_not @user.valid?
    assert_not_empty @user.errors[:public_id]
  end

  test "association deletion: destroys dependent user_emails" do
    email = UserEmail.create!(user: @user, address: "delete_test@example.com")
    assert_difference("UserEmail.count", -1) do
      @user.destroy
    end
    assert_raise(ActiveRecord::RecordNotFound) { email.reload }
  end

  test "association deletion: destroys dependent user_telephones" do
    phone = UserTelephone.create!(user: @user, number: "+15551234567")
    assert_difference("UserTelephone.count", -1) do
      @user.destroy
    end
    assert_raise(ActiveRecord::RecordNotFound) { phone.reload }
  end

  test "association deletion: destroys dependent user_tokens" do
    token = UserToken.create!(
      user: @user,
      lapses_at: 1.day.from_now,
    )
    assert_difference("UserToken.count", -@user.user_tokens.count) do
      @user.destroy
    end
    assert_raise(ActiveRecord::RecordNotFound) { token.reload }
  end

  test "owned_avatars association" do
    capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
    handle = Handle.create!(
      handle: "owned_handle-#{SecureRandom.hex(4)}",
      cooldown_until: Time.current,
    )
    avatar = Avatar.create!(capability: capability, active_handle: handle, moniker: "Owned")
    avatar.avatar_assignments.create!(user: @user, role: "owner")

    assert_includes @user.owned_avatars, avatar
  end

  test "purge_at query picks users with past purge_at" do
    user = User.create!(public_id: "u_#{SecureRandom.hex(8)}", lapses_at: 2.hours.ago, purge_at: 1.hour.ago)

    assert_includes User.where(purge_at: ..Time.current), user
  end

  test "purge_at query excludes users with future purge_at" do
    user = User.create!(
      public_id: "u_#{SecureRandom.hex(8)}", lapses_at: 30.minutes.from_now,
      purge_at: 1.hour.from_now,
    )

    assert_not_includes User.where(purge_at: ..Time.current), user
  end

  test "purge_at query excludes users with default purge_at" do
    user = User.create!(public_id: "u_#{SecureRandom.hex(8)}")

    assert_not_includes User.where(purge_at: ..Time.current), user
  end

  test "totp_enabled? returns false when no totp" do
    assert_not @user.totp_enabled?
  end

  test "totp_enabled? returns true when active totp exists" do
    UserOneTimePassword.create!(
      user: @user,
      user_identity_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE,
    )

    assert_predicate @user, :totp_enabled?
  end

  test "totp_enabled? returns false when totp is not active" do
    UserOneTimePassword.create!(
      user: @user,
      user_identity_one_time_password_status_id: UserOneTimePasswordStatus::INACTIVE,
    )

    assert_not @user.totp_enabled?
  end

  test "user_social_googles returns array with google when present" do
    google = UserSocialGoogle.create!(
      user: @user,
      status_id: UserSocialGoogleStatus::ACTIVE,
      token: "test_token",
      uid: "test_uid",
      token_expires_at: 1.day.from_now,
    )

    assert_equal [google], @user.user_social_googles
  end

  test "user_social_googles returns empty array when no google" do
    assert_equal [], @user.user_social_googles
  end

  test "withdrawal_started? returns false when not started" do
    assert_not @user.withdrawal_started?
  end

  test "withdrawal_started? returns true when started" do
    @user.update!(withdrawal_started_at: Time.current)

    assert_predicate @user, :withdrawal_started?
  end

  test "deactivated? returns false when not deactivated" do
    assert_not @user.deactivated?
  end

  test "deactivated? returns true when deactivated" do
    @user.update!(deactivated_at: Time.current)

    assert_predicate @user, :deactivated?
  end

  test "login_methods_remaining? returns false when no methods" do
    assert_not @user.login_methods_remaining?
  end

  test "login_methods_remaining? returns true when email verified" do
    UserEmail.create!(
      user: @user,
      address: "verified@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
      confirm_policy: "1",
    )

    assert_predicate @user, :login_methods_remaining?
  end

  test "remaining_login_methods returns email when verified" do
    UserEmail.create!(
      user: @user,
      address: "verified@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
      confirm_policy: "1",
    )

    methods = @user.remaining_login_methods

    assert_includes methods, :email
  end

  test "verified_email? returns true with verified email" do
    UserEmail.create!(
      user: @user,
      address: "verified@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
      confirm_policy: "1",
    )

    assert_predicate @user, :verified_email?
  end

  test "verified_email? returns false with unverified email" do
    UserEmail.create!(
      user: @user,
      address: "unverified@example.com",
      user_email_status_id: UserEmailStatus::UNVERIFIED,
      confirm_policy: "1",
    )

    assert_not @user.verified_email?
  end

  test "verified_telephone? returns true with verified telephone" do
    UserTelephone.create!(
      user: @user,
      number: "+15551234567",
      user_identity_telephone_status_id: UserTelephoneStatus::VERIFIED,
    )

    assert_predicate @user, :verified_telephone?
  end

  test "verified_telephone? returns true with loaded verified telephone association" do
    UserTelephone.create!(
      user: @user,
      number: "+15557654321",
      user_identity_telephone_status_id: UserTelephoneStatus::VERIFIED,
    )

    @user.user_telephones.load

    assert_predicate @user, :verified_telephone?
  end

  test "verified_telephone? returns false with unverified telephone" do
    UserTelephone.create!(
      user: @user,
      number: "+15551234567",
      user_identity_telephone_status_id: UserTelephoneStatus::UNVERIFIED,
    )

    assert_not @user.verified_telephone?
  end

  test "passkey_login_available? returns false when no passkeys" do
    assert_not @user.passkey_login_available?
  end

  test "has_verified_pii? returns true with verified email" do
    UserEmail.create!(
      user: @user,
      address: "verified@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
      confirm_policy: "1",
    )

    assert_predicate @user, :has_verified_pii?
  end

  test "has_verified_pii? returns true with verified telephone" do
    UserTelephone.create!(
      user: @user,
      number: "+15551234567",
      user_identity_telephone_status_id: UserTelephoneStatus::VERIFIED,
    )

    assert_predicate @user, :has_verified_pii?
  end

  test "has_verified_pii? returns false with no verified identity" do
    assert_not @user.has_verified_pii?
  end

  test "has_verified_recovery_identity? delegates to has_verified_pii?" do
    assert_equal @user.has_verified_pii?, @user.has_verified_recovery_identity?
  end

  test "active_social_provider? returns false when no social provider" do
    assert_not @user.active_social_provider?("google")
    assert_not @user.active_social_provider?("apple")
  end

  test "active_social_provider? returns true for active google" do
    UserSocialGoogle.create!(
      user: @user,
      status_id: UserSocialGoogleStatus::ACTIVE,
      token: "test_token",
      uid: "test_uid",
      token_expires_at: 1.day.from_now,
    )

    assert @user.active_social_provider?("google")
  end

  test "active_social_provider? returns true for active apple" do
    UserSocialApple.create!(
      user: @user,
      status_id: UserSocialAppleStatus::ACTIVE,
      token: "test_token",
      uid: "test_uid",
      token_expires_at: 1.day.from_now,
    )

    assert @user.active_social_provider?("apple")
  end

  test "remaining_login_methods excludes provider when specified" do
    UserSocialGoogle.create!(
      user: @user,
      status_id: UserSocialGoogleStatus::ACTIVE,
      token: "test_token",
      uid: "test_uid",
      token_expires_at: 1.day.from_now,
    )
    UserEmail.create!(
      user: @user,
      address: "verified@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
      confirm_policy: "1",
    )

    methods = @user.remaining_login_methods(excluding_provider: "google")

    assert_not_includes methods, :google
    assert_includes methods, :email
  end

  test "withdrawal_in_progress? returns false when not started" do
    assert_not @user.withdrawal_in_progress?
  end

  test "withdrawal_in_progress? returns true when withdrawal started" do
    @user.update!(withdrawal_started_at: Time.current)

    assert_predicate @user, :withdrawal_in_progress?
  end

  test "withdrawal_in_progress? returns true when deactivated" do
    @user.update!(deactivated_at: Time.current)

    assert_predicate @user, :withdrawal_in_progress?
  end

  test "passkey_login_available? returns true when passkey and phone verified" do
    UserTelephone.create!(
      user: @user,
      number: "+15551234567",
      user_identity_telephone_status_id: UserTelephoneStatus::VERIFIED,
    )
    UserPasskey.create!(
      user: @user,
      status_id: UserPasskeyStatus::ACTIVE,
      public_key: "test_key",
      webauthn_id: "test_webauthn_id",
      description: "My Passkey",
    )

    assert_predicate @user, :passkey_login_available?
  end

  test "remaining_login_methods returns apple when active" do
    UserSocialApple.create!(
      user: @user,
      status_id: UserSocialAppleStatus::ACTIVE,
      token: "test_token",
      uid: "apple_uid",
      token_expires_at: 1.day.from_now,
    )

    assert_includes @user.remaining_login_methods, :apple
  end

  test "remaining_login_methods returns passkey when available" do
    UserTelephone.create!(
      user: @user,
      number: "+15551234567",
      user_identity_telephone_status_id: UserTelephoneStatus::VERIFIED,
    )
    UserPasskey.create!(
      user: @user,
      status_id: UserPasskeyStatus::ACTIVE,
      public_key: "test_key",
      webauthn_id: "test_webauthn_id",
      description: "My Passkey",
    )

    assert_includes @user.remaining_login_methods, :passkey
  end

  private

  def root_workspace
    Workspace.find_or_create_by!(id: NIL_UUID) do |workspace|
      workspace.name = "Root Workspace"
      workspace.domain = "root.example.com"
      workspace.parent_organization = NIL_UUID
    end
  end
end
