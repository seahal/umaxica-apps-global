# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: clients
# Database name: app_principal
#
#  id                    :bigint           not null, primary key
#  birthdate             :text
#  deactivated_at        :datetime
#  discarded_at          :datetime         default(Infinity), not null
#  last_step_up_at       :datetime
#  lock_version          :integer          default(0), not null
#  mfa_level_enabled     :boolean          default(FALSE), not null
#  purged_at             :datetime         default(Infinity), not null
#  terminated_at         :datetime
#  withdrawal_started_at :datetime
#  withdrawn_at          :datetime         default(Infinity)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  mfa_level_id          :bigint           default(0), not null
#  mfa_status_id         :bigint           default(5), not null
#  public_id             :string(255)      default(""), not null
#  status_id             :bigint           default(11), not null
#  visibility_id         :bigint           default(2), not null
#
# Indexes
#
#  index_clients_on_deactivated_at         (deactivated_at) WHERE (deactivated_at IS NOT NULL)
#  index_clients_on_discarded_at           (discarded_at)
#  index_clients_on_mfa_level_id           (mfa_level_id)
#  index_clients_on_mfa_status_id          (mfa_status_id)
#  index_clients_on_public_id              (public_id) UNIQUE
#  index_clients_on_purged_at              (purged_at) WHERE (purged_at IS NOT NULL)
#  index_clients_on_status_id              (status_id)
#  index_clients_on_terminated_at          (terminated_at) WHERE (terminated_at IS NOT NULL)
#  index_clients_on_visibility_id          (visibility_id)
#  index_clients_on_withdrawal_started_at  (withdrawal_started_at) WHERE (withdrawal_started_at IS NOT NULL)
#  index_clients_on_withdrawn_at           (withdrawn_at) WHERE (withdrawn_at IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (mfa_level_id => client_mfa_levels.id)
#  fk_rails_...  (mfa_status_id => client_mfa_statuses.id)
#  fk_rails_...  (status_id => client_statuses.id)
#  fk_rails_...  (visibility_id => client_visibilities.id)
#

require "test_helper"

class ClientTest < ActiveSupport::TestCase
  NIL_UUID = "00000000-0000-0000-0000-000000000000"

  def setup
    Prosopite.pause do
      [0, 1, 2, 3].each { |id| ClientVisibility.find_or_create_by!(id: id) }
    end

    @user =
      Client.create!(public_id: "u_#{SecureRandom.hex(8)}") do |u|
        u.status_id = ClientStatus::NOTHING
      end
  end

  test "should be valid" do
    assert_predicate @user, :valid?
  end

  test "should have timestamps" do
    assert_not_nil @user.created_at
    assert_not_nil @user.updated_at
  end

  test "should have one user_apple_identity association" do
    assert_respond_to @user, :user_apple_identity
    assert_equal :has_one, @user.class.reflect_on_association(:user_apple_identity).macro
  end

  test "should have one user_google_identity association" do
    assert_respond_to @user, :user_google_identity
    assert_equal :has_one, @user.class.reflect_on_association(:user_google_identity).macro
  end

  test "staff? should return false" do
    assert_not @user.staff?
  end

  test "user? should return true" do
    assert_predicate @user, :user?
  end

  test "should set default status before creation" do
    user = Client.create!

    assert_equal ClientStatus::NOTHING, user.status_id
  end

  test "database default status matches the nothing status" do
    status_column = Client.columns.find { |column| column.name == "status_id" }

    assert_equal ClientStatus::NOTHING, status_column.default.to_i
  end

  test "should default visibility_id to staff (2)" do
    user = Client.create!

    assert_equal ClientVisibility::STAFF, user.visibility_id
  end

  test "login_allowed? is false for reserved status" do
    @user.update!(status_id: ClientStatus::RESERVED)

    assert_not @user.login_allowed?
  end

  test "login_allowed? remains true for nothing status while active" do
    assert_predicate @user, :login_allowed?
  end

  test "mfa_level_enabled and mfa_level_id must describe the same requirement" do
    user = Client.new(mfa_level_enabled: true, mfa_level_id: ClientMfaLevel::NOTHING)

    assert_not user.valid?
    assert_not_empty user.errors[:mfa_level_id]

    user = Client.new(mfa_level_enabled: false, mfa_level_id: ClientMfaLevel::FULL)

    assert_not user.valid?
    assert_not_empty user.errors[:mfa_level_enabled]
  end

  test "termination requires finite withdrawal completion" do
    user = Client.new(terminated_at: Time.current)

    assert_not user.valid?
    assert_not_empty user.errors[:terminated_at]

    user.withdrawn_at = 1.minute.ago

    assert_predicate user, :valid?
  end

  test "withdrawal completion cannot precede withdrawal start" do
    user = Client.new(withdrawal_started_at: Time.current, withdrawn_at: 1.minute.ago)

    assert_not user.valid?
    assert_not_empty user.errors[:withdrawn_at]
  end

  test "visibility association resolves to ClientVisibility with id 2 by default" do
    user = Client.create!

    assert_equal ClientVisibility::STAFF, user.visibility.id
  end

  test "invalid visibility_id is rejected by foreign key" do
    user = Client.new(
      public_id: "u_fk_#{SecureRandom.hex(6)}",
      status_id: ClientStatus::NOTHING,
      visibility_id: 9_999,
    )
    assert_raises(ActiveRecord::InvalidForeignKey) do
      user.save!(validate: false)
    end
  end

  test "should have many client_emails association" do
    assert_respond_to @user, :client_emails
    assert_equal :has_many, @user.class.reflect_on_association(:client_emails).macro
  end

  test "should have many client_secret_credentials association" do
    assert_respond_to @user, :client_secret_credentials
    assert_equal :has_many, @user.class.reflect_on_association(:client_secret_credentials).macro
  end

  test "should have many client_passkeys association" do
    assert_respond_to @user, :client_passkeys
    assert_equal :has_many, @user.class.reflect_on_association(:client_passkeys).macro
  end

  test "boundary values: public_id must be unique" do
    @user.public_id = "duplicate-id"
    @user.save!

    duplicate_user = Client.new(public_id: "duplicate-id")

    assert_not duplicate_user.valid?
    assert_not_empty duplicate_user.errors[:public_id]
  end

  test "boundary values: public_id length" do
    @user.public_id = "a" * 22

    assert_not @user.valid?
    assert_not_empty @user.errors[:public_id]
  end

  test "association deletion: destroys dependent client_emails" do
    email = ClientEmail.create!(user: @user, address: "delete_test@example.com")
    assert_difference("ClientEmail.count", -1) do
      @user.destroy
    end
    assert_raise(ActiveRecord::RecordNotFound) { email.reload }
  end

  test "association deletion: destroys dependent client_telephones" do
    phone = ClientTelephone.create!(user: @user, number: "+15551234567")
    assert_difference("ClientTelephone.count", -1) do
      @user.destroy
    end
    assert_raise(ActiveRecord::RecordNotFound) { phone.reload }
  end

  test "association deletion: destroys dependent client_tokens" do
    token = ClientToken.create!(
      user: @user,
      discarded_at: 1.day.from_now,
    )
    assert_difference("ClientToken.count", -@user.client_tokens.count) do
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
    member = Member.create!(user: @user, public_id: "m_#{SecureRandom.hex(8)}")
    avatar = Avatar.create!(member: member, capability: capability, active_handle: handle, moniker: "Owned")
    avatar.avatar_assignments.create!(user: @user, role: "owner")

    assert_includes @user.owned_avatars, avatar
  end

  test "purged_at query picks clients with past purged_at" do
    user = Client.create!(public_id: "u_#{SecureRandom.hex(8)}", discarded_at: 2.hours.ago, purged_at: 1.hour.ago)

    assert_includes Client.where(purged_at: ..Time.current), user
  end

  test "purged_at query excludes clients with future purged_at" do
    user = Client.create!(
      public_id: "u_#{SecureRandom.hex(8)}", discarded_at: 30.minutes.from_now,
      purged_at: 1.hour.from_now,
    )

    assert_not_includes Client.where(purged_at: ..Time.current), user
  end

  test "purged_at query excludes clients with default purged_at" do
    user = Client.create!(public_id: "u_#{SecureRandom.hex(8)}")

    assert_not_includes Client.where(purged_at: ..Time.current), user
  end

  test "totp_enabled? returns false when no totp" do
    assert_not @user.totp_enabled?
  end

  test "totp_enabled? returns true when active totp exists" do
    ClientTotpCredential.create!(
      user: @user,
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )

    assert_predicate @user, :totp_enabled?
  end

  test "totp_enabled? returns false when totp is not active" do
    ClientTotpCredential.create!(
      user: @user,
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::INACTIVE,
    )

    assert_not @user.totp_enabled?
  end

  test "client_google_identities returns array with google when present" do
    google = ClientGoogleIdentity.create!(
      user: @user,
      status_id: ClientGoogleIdentityStatus::ACTIVE,
      token: "test_token",
      uid: "test_uid",
      token_expires_at: 1.day.from_now,
    )

    assert_equal [google], @user.client_google_identities
  end

  test "client_google_identities returns empty array when no google" do
    assert_equal [], @user.client_google_identities
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
    ClientEmail.create!(
      user: @user,
      address: "verified@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      confirm_policy: "1",
    )

    assert_predicate @user, :login_methods_remaining?
  end

  test "remaining_login_methods returns email when verified" do
    ClientEmail.create!(
      user: @user,
      address: "verified@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      confirm_policy: "1",
    )

    methods = @user.remaining_login_methods

    assert_includes methods, :email
  end

  test "verified_email? returns true with verified email" do
    ClientEmail.create!(
      user: @user,
      address: "verified@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      confirm_policy: "1",
    )

    assert_predicate @user, :verified_email?
  end

  test "verified_email? returns false with unverified email" do
    ClientEmail.create!(
      user: @user,
      address: "unverified@example.com",
      user_email_status_id: ClientEmailStatus::UNVERIFIED,
      confirm_policy: "1",
    )

    assert_not @user.verified_email?
  end

  test "verified_telephone? returns true with verified telephone" do
    ClientTelephone.create!(
      user: @user,
      number: "+15551234567",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    assert_predicate @user, :verified_telephone?
  end

  test "verified_telephone? returns true with loaded verified telephone association" do
    ClientTelephone.create!(
      user: @user,
      number: "+15557654321",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    @user.client_telephones.load

    assert_predicate @user, :verified_telephone?
  end

  test "verified_telephone? returns false with unverified telephone" do
    ClientTelephone.create!(
      user: @user,
      number: "+15551234567",
      user_identity_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
    )

    assert_not @user.verified_telephone?
  end

  test "passkey_login_available? returns false when no passkeys" do
    assert_not @user.passkey_login_available?
  end

  test "has_verified_pii? returns true with verified email" do
    ClientEmail.create!(
      user: @user,
      address: "verified@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      confirm_policy: "1",
    )

    assert_predicate @user, :has_verified_pii?
  end

  test "has_verified_pii? returns true with verified telephone" do
    ClientTelephone.create!(
      user: @user,
      number: "+15551234567",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
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
    ClientGoogleIdentity.create!(
      user: @user,
      status_id: ClientGoogleIdentityStatus::ACTIVE,
      token: "test_token",
      uid: "test_uid",
      token_expires_at: 1.day.from_now,
    )

    assert @user.active_social_provider?("google")
  end

  test "active_social_provider? returns true for active apple" do
    ClientAppleIdentity.create!(
      user: @user,
      status_id: ClientAppleIdentityStatus::ACTIVE,
      token: "test_token",
      uid: "test_uid",
      token_expires_at: 1.day.from_now,
    )

    assert @user.active_social_provider?("apple")
  end

  test "remaining_login_methods excludes provider when specified" do
    ClientGoogleIdentity.create!(
      user: @user,
      status_id: ClientGoogleIdentityStatus::ACTIVE,
      token: "test_token",
      uid: "test_uid",
      token_expires_at: 1.day.from_now,
    )
    ClientEmail.create!(
      user: @user,
      address: "verified@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      confirm_policy: "1",
    )

    methods = @user.remaining_login_methods(excluding_provider: "google")

    assert_not_includes methods, :google
    assert_includes methods, :email
  end

  test "remaining_social_unlink_methods ignores stale social association cache" do
    assert_nil @user.user_apple_identity

    ClientAppleIdentity.create!(
      user: @user,
      status_id: ClientAppleIdentityStatus::ACTIVE,
      token: "test_token",
      uid: "cached_apple_uid",
      token_expires_at: 1.day.from_now,
    )

    assert_includes @user.remaining_social_unlink_methods(excluding_provider: "google_app"), :apple
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
    ClientTelephone.create!(
      user: @user,
      number: "+15551234567",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )
    ClientPasskey.create!(
      user: @user,
      status_id: ClientPasskeyStatus::ACTIVE,
      public_key: "test_key",
      webauthn_id: "test_webauthn_id",
      description: "My Passkey",
    )

    assert_predicate @user, :passkey_login_available?
  end

  test "remaining_login_methods returns apple when active" do
    ClientAppleIdentity.create!(
      user: @user,
      status_id: ClientAppleIdentityStatus::ACTIVE,
      token: "test_token",
      uid: "apple_uid",
      token_expires_at: 1.day.from_now,
    )

    assert_includes @user.remaining_login_methods, :apple
  end

  test "remaining_login_methods returns passkey when available" do
    ClientTelephone.create!(
      user: @user,
      number: "+15551234567",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )
    ClientPasskey.create!(
      user: @user,
      status_id: ClientPasskeyStatus::ACTIVE,
      public_key: "test_key",
      webauthn_id: "test_webauthn_id",
      description: "My Passkey",
    )

    assert_includes @user.remaining_login_methods, :passkey
  end
end
