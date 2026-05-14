# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_secrets
# Database name: principal
#
#  id                             :bigint           not null, primary key
#  lapses_at                      :datetime         default(Infinity), not null
#  last_used_at                   :datetime
#  name                           :string           default(""), not null
#  password_digest                :string           default(""), not null
#  purge_at                       :datetime         default(Infinity), not null
#  uses_remaining                 :integer          default(1), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  public_id                      :string(21)       not null
#  user_id                        :bigint           not null
#  user_identity_secret_status_id :bigint           default(1), not null
#  user_secret_kind_id            :bigint           default(1), not null
#
# Indexes
#
#  index_user_secrets_on_public_id                       (public_id) UNIQUE
#  index_user_secrets_on_user_id                         (user_id)
#  index_user_secrets_on_user_identity_secret_status_id  (user_identity_secret_status_id)
#  index_user_secrets_on_user_secret_kind_id             (user_secret_kind_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#  fk_rails_...  (user_identity_secret_status_id => user_secret_statuses.id)
#  fk_rails_...  (user_secret_kind_id => user_secret_kinds.id)
#

require "test_helper"
require "concurrent"

class UserSecretTest < ActiveSupport::TestCase
  setup do
    UserStatus.find_or_create_by!(id: UserStatus::NOTHING)
    # Also need UserSecretStatus as 'ACTIVE', 'USED', 'EXPIRED' are used in tests
    @active_status = UserSecretStatus.find_or_create_by!(id: UserSecretStatus::ACTIVE)
    UserSecretStatus.find_or_create_by!(id: UserSecretStatus::USED)
    UserSecretStatus.find_or_create_by!(id: UserSecretStatus::EXPIRED)
    # Set up UserSecretKind records
    @login_kind = UserSecretKind.find_or_create_by!(id: UserSecretKind::LOGIN)
    UserSecretKind.find_or_create_by!(id: UserSecretKind::TOTP)
    UserSecretKind.find_or_create_by!(id: UserSecretKind::RECOVERY)
    UserSecretKind.find_or_create_by!(id: UserSecretKind::API)
    UserEmailStatus.find_or_create_by!(id: UserEmailStatus::VERIFIED)

    @user =
      User.create!(public_id: "u_#{SecureRandom.hex(8)}") do |u|
        u.status_id = UserStatus::NOTHING
      end
    UserEmail.create!(
      user: @user,
      address: "secret-model-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    # Preload to avoid N+1 in validations
    @user.user_emails.load
    @user.user_secrets.load
  end

  test "allows up to the maximum number of secrets per user" do
    UserSecret::MAX_SECRETS_PER_USER.times do
      create_secret!
    end

    assert_equal UserSecret::MAX_SECRETS_PER_USER,
                 UserSecret.where(user: @user).count
  end

  test "rejects creating more than the maximum secrets per user" do
    UserSecret::MAX_SECRETS_PER_USER.times { create_secret! }

    assert_raises(ActiveRecord::RecordInvalid) { create_secret! }
  end

  test "issue! returns raw secret and persists a digest" do
    record, raw_secret = UserSecret.issue!(name: "API Key", user: @user, user_secret_kind_id: UserSecretKind::LOGIN)

    assert_predicate record, :persisted?
    assert_predicate raw_secret, :present?
    assert record.authenticate(raw_secret)
    assert_not_includes record.attributes.values, raw_secret
  end

  test "verify_and_consume! decrements uses_remaining" do
    record, raw_secret = UserSecret.issue!(name: "API Key", user: @user, uses: 2, user_secret_kind_id: UserSecretKind::LOGIN)

    assert record.verify_and_consume!(raw_secret)
    assert_equal 1, record.reload.uses_remaining
  end

  test "verify_and_consume! marks used when uses_remaining reaches zero" do
    record, raw_secret = UserSecret.issue!(name: "API Key", user: @user, uses: 1, user_secret_kind_id: UserSecretKind::LOGIN)

    assert record.verify_and_consume!(raw_secret)
    assert_equal UserSecretStatus::USED, record.reload.user_secret_status_id
  end

  test "verify_and_consume! expires secrets past their expiry" do
    record, raw_secret = UserSecret.issue!(
      name: "API Key",
      user: @user,
      user_secret_kind_id: UserSecretKind::LOGIN,
    )
    record.update_columns(lapses_at: 1.minute.ago, created_at: 2.minutes.ago)

    assert_not record.verify_and_consume!(raw_secret)
    assert_equal UserSecretStatus::EXPIRED, record.reload.user_secret_status_id
  end

  test "verify_and_consume! only allows one consumer for a single use" do
    record, raw_secret = UserSecret.issue!(name: "API Key", user: @user, uses: 1, user_secret_kind_id: UserSecretKind::LOGIN)
    gate = Queue.new

    futures =
      2.times.map do
        Concurrent::Future.execute do
          ActiveRecord::Base.connection_pool.with_connection do
            gate.pop
            UserSecret.find(record.id).verify_and_consume!(raw_secret)
          end
        end
      end

    2.times { gate << true }
    results = futures.map(&:value!)

    assert_equal 1, results.count(true)
    assert_equal 0, record.reload.uses_remaining
  end

  test "invalid when password_digest is nil" do
    record = UserSecret.new(user: @user, name: "Key", password: nil)

    assert_not record.valid?
    assert_not_empty record.errors[:password_digest]
  end

  test "name length boundary" do
    record = UserSecret.new(user: @user, name: "a" * 256, password: "SecretPass123!")

    assert_not record.valid?
    assert_not_empty record.errors[:name]
  end

  test "association deletion: destroys when user is destroyed" do
    record, _raw = UserSecret.issue!(name: "Cleanup Test", user: @user, user_secret_kind_id: UserSecretKind::LOGIN)
    @user.destroy
    assert_raise(ActiveRecord::RecordNotFound) { record.reload }
  end

  test "generate_raw_secret returns base58 string of expected length" do
    secret = UserSecret.generate_raw_secret(length: 32)

    assert_equal 32, secret.length
    assert_match(/\A[1-9A-HJ-NP-Za-km-z]+\z/, secret)
  end

  test "sample fixture secret authenticates with fixed raw secret" do
    secret = user_secrets(:sample_login)

    assert secret.authenticate("00000000000000000000000000000000")
    assert_equal UserSecretKind::PERMANENT, secret.user_secret_kind_id
    assert_equal UserSecretStatus::ACTIVE, secret.user_secret_status_id
  end

  test "value maps to password accessor" do
    record = UserSecret.new(user: @user, name: "Key")

    record.value = secure_secret

    assert_equal record.password, record.value
  end

  test "enabled? reflects active status" do
    record = UserSecret.new(user: @user, name: "Key")
    record.user_secret_status_id = UserSecretStatus::ACTIVE

    assert_predicate record, :enabled?

    record.user_secret_status_id = UserSecretStatus::REVOKED

    assert_not record.enabled?
  end

  test "usable_for_secret_sign_in? rejects revoked kind and expired secrets" do
    record, _raw = UserSecret.issue!(name: "Sign In Secret", user: @user, user_secret_kind_id: UserSecretKind::LOGIN)

    assert_predicate record, :usable_for_secret_sign_in?

    record.user_identity_secret_status_id = UserSecretStatus::REVOKED

    assert_not record.usable_for_secret_sign_in?

    record.user_identity_secret_status_id = UserSecretStatus::ACTIVE
    record.user_secret_kind_id = UserSecretKind::TOTP

    assert_not record.usable_for_secret_sign_in?

    record.user_secret_kind_id = UserSecretKind::LOGIN
    record.define_singleton_method(:lapses_at) { 1.minute.ago }

    assert_not record.usable_for_secret_sign_in?

    record.define_singleton_method(:lapses_at) { nil }

    assert_predicate record, :usable_for_secret_sign_in?
  end

  test "verify_for_secret_sign_in! rejects wrong secret and disallowed states" do
    record, raw_secret = UserSecret.issue!(name: "Sign In Secret", user: @user, user_secret_kind_id: UserSecretKind::LOGIN)

    assert_not record.verify_for_secret_sign_in!("wrong-secret")

    record.update!(user_identity_secret_status_id: UserSecretStatus::REVOKED)

    assert_not record.verify_for_secret_sign_in!(raw_secret)

    record.update!(
      user_identity_secret_status_id: UserSecretStatus::ACTIVE,
      user_secret_kind_id: UserSecretKind::TOTP,
    )

    assert_not record.verify_for_secret_sign_in!(raw_secret)
  end

  test "validates kind_id is required" do
    record = UserSecret.new(
      user: @user,
      name: "Test Secret",
      password: secure_secret,
      user_secret_kind_id: nil,
    )

    assert_not record.valid?
    assert_not_empty record.errors[:user_secret_kind]
  end

  test "login_secret? predicate returns true for LOGIN kind" do
    record = UserSecret.new(user: @user, name: "Key", user_secret_kind_id: UserSecretKind::LOGIN)

    assert_predicate record, :login_secret?
    assert_not record.totp_secret?
    assert_not record.recovery_secret?
    assert_not record.api_secret?
  end

  test "totp_secret? predicate returns true for TOTP kind" do
    record = UserSecret.new(user: @user, name: "Key", user_secret_kind_id: UserSecretKind::TOTP)

    assert_predicate record, :totp_secret?
    assert_not record.login_secret?
  end

  test "recovery_secret? predicate returns true for RECOVERY kind" do
    record = UserSecret.new(user: @user, name: "Key", user_secret_kind_id: UserSecretKind::RECOVERY)

    assert_predicate record, :recovery_secret?
    assert_not record.login_secret?
  end

  test "api_secret? predicate returns true for API kind" do
    record = UserSecret.new(user: @user, name: "Key", user_secret_kind_id: UserSecretKind::API)

    assert_predicate record, :api_secret?
    assert_not record.login_secret?
  end

  test "public_id is automatically generated on create" do
    record = UserSecret.create!(
      user: @user,
      name: "Test Secret",
      password: secure_secret,
      user_secret_kind_id: UserSecretKind::LOGIN,
    )

    assert_predicate record.public_id, :present?
    assert_equal 21, record.public_id.length
  end

  test "to_param returns public_id" do
    record = UserSecret.create!(
      user: @user,
      name: "Test Secret",
      password: secure_secret,
      user_secret_kind_id: UserSecretKind::LOGIN,
    )

    assert_equal record.public_id, record.to_param
  end

  test "public_id is unique" do
    record1 = UserSecret.create!(
      user: @user,
      name: "Test Secret 1",
      password: secure_secret,
      user_secret_kind_id: UserSecretKind::LOGIN,
    )

    record2 = UserSecret.new(
      user: @user,
      name: "Test Secret 2",
      password: secure_secret,
      user_secret_kind_id: UserSecretKind::LOGIN,
    )
    record2.public_id = record1.public_id

    assert_not record2.valid?
    assert_not_empty record2.errors[:public_id]
  end

  test "is invalid on create when user has no verified recovery identity" do
    user_without_identity =
      User.create!(public_id: "u_#{SecureRandom.hex(8)}") do |u|
        u.status_id = UserStatus::NOTHING
      end

    record = UserSecret.new(
      user: user_without_identity,
      name: "No Identity Secret",
      password: secure_secret,
      password_confirmation: secure_secret,
      user_secret_kind_id: UserSecretKind::LOGIN,
    )

    assert_not record.valid?
    assert_includes record.errors[:base], User::RECOVERY_IDENTITY_REQUIRED_MESSAGE
  end

  private

  def create_secret!
    UserSecret.create!(
      user: @user,
      name: "Secret-#{SecureRandom.hex(4)}",
      password: secure_secret,
      password_confirmation: secure_secret,
      user_secret_kind: @login_kind,
      user_secret_status: @active_status,
    )
  end

  def secure_secret
    SecureRandom.base58(Secret::SECRET_PASSWORD_LENGTH)
  end
end
