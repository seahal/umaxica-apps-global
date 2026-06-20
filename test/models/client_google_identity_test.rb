# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_google_identities
# Database name: app_principal
#
#  id                    :bigint           not null, primary key
#  discarded_at          :datetime         default(Infinity), not null
#  last_authenticated_at :datetime
#  provider              :string           default("google_app"), not null
#  purged_at             :datetime         default(Infinity), not null
#  refresh_token         :string           default(""), not null
#  token                 :string           default(""), not null
#  token_expires_at      :integer          not null
#  uid                   :string           default(""), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  status_id             :bigint           default(1), not null
#  user_id               :bigint           not null
#
# Indexes
#
#  index_client_google_identities_on_discarded_at        (discarded_at)
#  index_client_google_identities_on_purged_at           (purged_at)
#  index_client_google_identities_on_status_id           (status_id)
#  index_client_google_identities_on_token_expires_at    (token_expires_at)
#  index_client_google_identities_on_uid_and_provider    (uid,provider) UNIQUE
#  index_user_identity_social_googles_on_user_id_unique  (user_id) UNIQUE WHERE (user_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => client_google_identity_statuses.id)
#  fk_rails_...  (user_id => clients.id)
#

require "test_helper"

class ClientGoogleIdentityTest < ActiveSupport::TestCase
  fixtures :clients, :client_google_identity_statuses, :client_google_identities

  test "allows only one google auth per user" do
    user = Client.find_by!(public_id: "one_id")

    ClientGoogleIdentity.create!(
      user: user,
      uid: "uid-1",
      token: "token-1",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: ClientGoogleIdentityStatus.find(ClientGoogleIdentityStatus::ACTIVE),
    )

    duplicate = ClientGoogleIdentity.new(
      user: user,
      token: "token-2",
    )

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:user_id]
  end

  test "token is required" do
    identity = ClientGoogleIdentity.new(user: Client.find_by!(public_id: "one_id"), uid: "uid", expires_at: 123)

    assert_not identity.valid?
    assert_not_empty identity.errors[:token]
  end

  test "uid is required" do
    identity = ClientGoogleIdentity.new(user: Client.find_by!(public_id: "one_id"), token: "token", expires_at: 123)

    assert_not identity.valid?
    assert_not_empty identity.errors[:uid]
  end

  test "expires_at is required" do
    identity = ClientGoogleIdentity.new(user: Client.find_by!(public_id: "one_id"), uid: "uid", token: "token")

    assert_not identity.valid?
    assert_not_empty identity.errors[:token_expires_at]
  end

  test "association deletion: destroys when user is destroyed" do
    user = Client.create!
    identity = ClientGoogleIdentity.create!(
      user: user,
      uid: "uid-cleanup",
      token: "token-cleanup",
      expires_at: 1.week.from_now.to_i,
    )
    user.destroy
    assert_raise(ActiveRecord::RecordNotFound) { identity.reload }
  end

  test "find_or_create_from_auth_hash initializes new record" do
    auth = MockAuth.new(
      uid: "new-google-uid",
      provider: "google",
      info: OpenStruct.new(email: "google@example.com"),
      credentials: OpenStruct.new(token: "google-token", expires_at: 123),
    )

    identity = ClientGoogleIdentity.find_or_create_from_auth_hash(auth)

    assert_predicate identity, :new_record?
    assert_equal "new-google-uid", identity.uid
    assert_equal "google", identity.provider
    assert_equal "google-token", identity.token
    assert_equal 123, identity.expires_at
  end

  test "find_or_create_from_auth_hash returns existing record with updated attributes" do
    user = clients(:one)
    ClientGoogleIdentity.create!(
      user: user,
      uid: "existing-google-uid",
      token: "old-token",
      expires_at: 123,
      user_google_identity_status: ClientGoogleIdentityStatus.find(ClientGoogleIdentityStatus::ACTIVE),
    )

    auth = MockAuth.new(
      uid: "existing-google-uid",
      provider: "google",
      info: OpenStruct.new(email: "updated-google@example.com"),
      credentials: OpenStruct.new(token: "updated-token", expires_at: 456),
    )

    identity = ClientGoogleIdentity.find_or_create_from_auth_hash(auth)

    assert_predicate identity, :persisted?
    assert_equal "updated-token", identity.token
    assert identity.changes.key?("token")
  end

  test "find_or_create_from_auth_hash preserves existing refresh token when omitted" do
    user = clients(:one)
    ClientGoogleIdentity.create!(
      user: user,
      uid: "refresh-google-uid",
      token: "old-token",
      refresh_token: "stored-refresh",
      expires_at: 123,
      user_google_identity_status: ClientGoogleIdentityStatus.find(ClientGoogleIdentityStatus::ACTIVE),
    )

    auth = MockAuth.new(
      uid: "refresh-google-uid",
      provider: "google",
      info: OpenStruct.new(email: "updated-google@example.com"),
      credentials: OpenStruct.new(token: "updated-token", refresh_token: nil, expires_at: 456),
    )

    identity = ClientGoogleIdentity.find_or_create_from_auth_hash(auth)

    assert_equal "stored-refresh", identity.refresh_token
  end

  test "find_or_create_from_auth_hash updates refresh token when present" do
    user = clients(:one)
    ClientGoogleIdentity.create!(
      user: user,
      uid: "present-refresh-google-uid",
      token: "old-token",
      refresh_token: "stored-refresh",
      expires_at: 123,
      user_google_identity_status: ClientGoogleIdentityStatus.find(ClientGoogleIdentityStatus::ACTIVE),
    )

    auth = MockAuth.new(
      uid: "present-refresh-google-uid",
      provider: "google",
      credentials: OpenStruct.new(token: "updated-token", refresh_token: "updated-refresh", expires_at: 456),
    )

    identity = ClientGoogleIdentity.find_or_create_from_auth_hash(auth)

    assert_equal "updated-refresh", identity.refresh_token
  end

  test "extract_uid does not fall back to extra raw_info sub" do
    auth = MockAuth.new(
      uid: "",
      provider: "google",
      info: OpenStruct.new(email: "google@example.com"),
      credentials: OpenStruct.new(token: "google-token", expires_at: 123),
      extra: OpenStruct.new(raw_info: OpenStruct.new(sub: "fallback-sub")),
    )

    assert_equal "", ClientGoogleIdentity.extract_uid(auth)
  end

  test "extract_uid uses uid when present" do
    auth = MockAuth.new(
      uid: "google-present-uid",
      provider: "google",
      info: OpenStruct.new(email: "google@example.com"),
      credentials: OpenStruct.new(token: "google-token", expires_at: 123),
    )

    assert_equal "google-present-uid", ClientGoogleIdentity.extract_uid(auth)
  end

  test "extract_uid returns empty string when uid and extra are missing" do
    auth = MockAuth.new(
      uid: nil,
      provider: "google",
      credentials: OpenStruct.new(token: "google-token", expires_at: 123),
    )

    assert_equal "", ClientGoogleIdentity.extract_uid(auth)
  end

  test "update_from_auth_hash updates attributes and timestamp" do
    identity = ClientGoogleIdentity.create!(
      user: clients(:one),
      uid: "update-google-uid",
      token: "old-token",
      refresh_token: "old-refresh",
      expires_at: 123,
    )

    auth = MockAuth.new(
      uid: "update-google-uid",
      provider: "google",
      info: OpenStruct.new(email: "new-google@example.com"),
      credentials: OpenStruct.new(token: "new-token", refresh_token: "new-refresh", expires_at: 456),
    )

    assert_nil identity.last_authenticated_at
    identity.update_from_auth_hash!(auth)

    assert_equal "new-token", identity.token
    assert_equal "new-refresh", identity.refresh_token
    assert_equal 456, identity.expires_at
    assert_predicate identity.last_authenticated_at, :present?
  end

  test "update_from_auth_hash preserves existing refresh token when omitted" do
    identity = ClientGoogleIdentity.create!(
      user: clients(:one),
      uid: "omit-refresh-google-uid",
      token: "old-token",
      refresh_token: "stored-refresh",
      expires_at: 123,
    )

    auth = MockAuth.new(
      uid: "omit-refresh-google-uid",
      provider: "google",
      info: OpenStruct.new(email: "new-google@example.com"),
      credentials: OpenStruct.new(token: "new-token", refresh_token: nil, expires_at: 456),
    )

    identity.update_from_auth_hash!(auth)

    assert_equal "stored-refresh", identity.refresh_token
  end

  test "active scope and active? check status column" do
    active = ClientGoogleIdentity.create!(
      user: clients(:two),
      uid: "active-google-uid",
      token: "token",
      expires_at: 123,
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )

    inactive = ClientGoogleIdentity.create!(
      user: Client.create!,
      uid: "inactive-google-uid",
      token: "token",
      expires_at: 123,
      status_id: ClientGoogleIdentityStatus::REVOKED,
    )

    assert_includes ClientGoogleIdentity.active, active
    assert_not_includes ClientGoogleIdentity.active, inactive
    assert_predicate active, :active?
    assert_not inactive.active?
  end

  test "normalized_provider maps provider" do
    identity = ClientGoogleIdentity.new(provider: "google")

    assert_equal "google", identity.normalized_provider
  end

  test "status_id uses the canonical status column" do
    identity = ClientGoogleIdentity.new(status_id: ClientGoogleIdentityStatus::ACTIVE)

    assert_equal ClientGoogleIdentityStatus::ACTIVE, identity.status_id
    assert_equal ClientGoogleIdentityStatus::ACTIVE, identity.status_id
    assert_equal ClientGoogleIdentityStatus::ACTIVE, identity.status_id
  end

  test "token_expires_at aliases expires_at" do
    identity = ClientGoogleIdentity.new(token_expires_at: 123)

    assert_equal 123, identity.token_expires_at
    assert_equal 123, identity.expires_at
  end

  class MockAuth < OpenStruct; end
end
