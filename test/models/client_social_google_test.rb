# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_social_googles
# Database name: app_principal
#
#  id                    :bigint           not null, primary key
#  last_authenticated_at :datetime
#  provider              :string           default("google_app"), not null
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
#  index_client_social_googles_on_status_id              (status_id)
#  index_client_social_googles_on_token_expires_at       (token_expires_at)
#  index_client_social_googles_on_uid_and_provider       (uid,provider) UNIQUE
#  index_user_identity_social_googles_on_user_id_unique  (user_id) UNIQUE WHERE (user_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => client_social_google_statuses.id)
#  fk_rails_...  (user_id => clients.id)
#

require "test_helper"

class ClientSocialGoogleTest < ActiveSupport::TestCase
  fixtures :clients, :client_social_google_statuses, :client_social_googles

  test "allows only one google auth per user" do
    user = Client.find_by!(public_id: "one_id")

    ClientSocialGoogle.create!(
      user: user,
      uid: "uid-1",
      token: "token-1",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: ClientSocialGoogleStatus.find(ClientSocialGoogleStatus::ACTIVE),
    )

    duplicate = ClientSocialGoogle.new(
      user: user,
      token: "token-2",
    )

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:user_id]
  end

  test "token is required" do
    identity = ClientSocialGoogle.new(user: Client.find_by!(public_id: "one_id"), uid: "uid", expires_at: 123)

    assert_not identity.valid?
    assert_not_empty identity.errors[:token]
  end

  test "uid is required" do
    identity = ClientSocialGoogle.new(user: Client.find_by!(public_id: "one_id"), token: "token", expires_at: 123)

    assert_not identity.valid?
    assert_not_empty identity.errors[:uid]
  end

  test "expires_at is required" do
    identity = ClientSocialGoogle.new(user: Client.find_by!(public_id: "one_id"), uid: "uid", token: "token")

    assert_not identity.valid?
    assert_not_empty identity.errors[:token_expires_at]
  end

  test "association deletion: destroys when user is destroyed" do
    user = Client.create!
    identity = ClientSocialGoogle.create!(
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
      provider: "google_app",
      info: OpenStruct.new(email: "google@example.com"),
      credentials: OpenStruct.new(token: "google-token", expires_at: 123),
    )

    identity = ClientSocialGoogle.find_or_create_from_auth_hash(auth)

    assert_predicate identity, :new_record?
    assert_equal "new-google-uid", identity.uid
    assert_equal "google_app", identity.provider
    assert_equal "google-token", identity.token
    assert_equal 123, identity.expires_at
  end

  test "find_or_create_from_auth_hash returns existing record with updated attributes" do
    user = clients(:one)
    ClientSocialGoogle.create!(
      user: user,
      uid: "existing-google-uid",
      token: "old-token",
      expires_at: 123,
      user_social_google_status: ClientSocialGoogleStatus.find(ClientSocialGoogleStatus::ACTIVE),
    )

    auth = MockAuth.new(
      uid: "existing-google-uid",
      provider: "google_app",
      info: OpenStruct.new(email: "updated-google@example.com"),
      credentials: OpenStruct.new(token: "updated-token", expires_at: 456),
    )

    identity = ClientSocialGoogle.find_or_create_from_auth_hash(auth)

    assert_predicate identity, :persisted?
    assert_equal "updated-token", identity.token
    assert identity.changes.key?("token")
  end

  test "find_or_create_from_auth_hash preserves existing refresh token when omitted" do
    user = clients(:one)
    ClientSocialGoogle.create!(
      user: user,
      uid: "refresh-google-uid",
      token: "old-token",
      refresh_token: "stored-refresh",
      expires_at: 123,
      user_social_google_status: ClientSocialGoogleStatus.find(ClientSocialGoogleStatus::ACTIVE),
    )

    auth = MockAuth.new(
      uid: "refresh-google-uid",
      provider: "google_app",
      info: OpenStruct.new(email: "updated-google@example.com"),
      credentials: OpenStruct.new(token: "updated-token", refresh_token: nil, expires_at: 456),
    )

    identity = ClientSocialGoogle.find_or_create_from_auth_hash(auth)

    assert_equal "stored-refresh", identity.refresh_token
  end

  test "find_or_create_from_auth_hash updates refresh token when present" do
    user = clients(:one)
    ClientSocialGoogle.create!(
      user: user,
      uid: "present-refresh-google-uid",
      token: "old-token",
      refresh_token: "stored-refresh",
      expires_at: 123,
      user_social_google_status: ClientSocialGoogleStatus.find(ClientSocialGoogleStatus::ACTIVE),
    )

    auth = MockAuth.new(
      uid: "present-refresh-google-uid",
      provider: "google_app",
      credentials: OpenStruct.new(token: "updated-token", refresh_token: "updated-refresh", expires_at: 456),
    )

    identity = ClientSocialGoogle.find_or_create_from_auth_hash(auth)

    assert_equal "updated-refresh", identity.refresh_token
  end

  test "extract_uid falls back to extra raw_info sub" do
    auth = MockAuth.new(
      uid: "",
      provider: "google_app",
      info: OpenStruct.new(email: "google@example.com"),
      credentials: OpenStruct.new(token: "google-token", expires_at: 123),
      extra: OpenStruct.new(raw_info: OpenStruct.new(sub: "fallback-sub")),
    )

    assert_equal "fallback-sub", ClientSocialGoogle.extract_uid(auth)
  end

  test "extract_uid uses uid when present" do
    auth = MockAuth.new(
      uid: "google-present-uid",
      provider: "google_app",
      info: OpenStruct.new(email: "google@example.com"),
      credentials: OpenStruct.new(token: "google-token", expires_at: 123),
    )

    assert_equal "google-present-uid", ClientSocialGoogle.extract_uid(auth)
  end

  test "extract_uid returns empty string when uid and extra are missing" do
    auth = MockAuth.new(
      uid: nil,
      provider: "google_app",
      credentials: OpenStruct.new(token: "google-token", expires_at: 123),
    )

    assert_equal "", ClientSocialGoogle.extract_uid(auth)
  end

  test "update_from_auth_hash updates attributes and timestamp" do
    identity = ClientSocialGoogle.create!(
      user: clients(:one),
      uid: "update-google-uid",
      token: "old-token",
      refresh_token: "old-refresh",
      expires_at: 123,
    )

    auth = MockAuth.new(
      uid: "update-google-uid",
      provider: "google_app",
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
    identity = ClientSocialGoogle.create!(
      user: clients(:one),
      uid: "omit-refresh-google-uid",
      token: "old-token",
      refresh_token: "stored-refresh",
      expires_at: 123,
    )

    auth = MockAuth.new(
      uid: "omit-refresh-google-uid",
      provider: "google_app",
      info: OpenStruct.new(email: "new-google@example.com"),
      credentials: OpenStruct.new(token: "new-token", refresh_token: nil, expires_at: 456),
    )

    identity.update_from_auth_hash!(auth)

    assert_equal "stored-refresh", identity.refresh_token
  end

  test "active scope and active? check status column" do
    active = ClientSocialGoogle.create!(
      user: clients(:two),
      uid: "active-google-uid",
      token: "token",
      expires_at: 123,
      status_id: ClientSocialGoogleStatus::ACTIVE,
    )

    inactive = ClientSocialGoogle.create!(
      user: Client.create!,
      uid: "inactive-google-uid",
      token: "token",
      expires_at: 123,
      status_id: ClientSocialGoogleStatus::REVOKED,
    )

    assert_includes ClientSocialGoogle.active, active
    assert_not_includes ClientSocialGoogle.active, inactive
    assert_predicate active, :active?
    assert_not inactive.active?
  end

  test "normalized_provider maps provider" do
    identity = ClientSocialGoogle.new(provider: "google_app")

    assert_equal "google", identity.normalized_provider
  end

  test "status_id uses the canonical status column" do
    identity = ClientSocialGoogle.new(status_id: ClientSocialGoogleStatus::ACTIVE)

    assert_equal ClientSocialGoogleStatus::ACTIVE, identity.status_id
    assert_equal ClientSocialGoogleStatus::ACTIVE, identity.status_id
    assert_equal ClientSocialGoogleStatus::ACTIVE, identity.status_id
  end

  test "token_expires_at aliases expires_at" do
    identity = ClientSocialGoogle.new(token_expires_at: 123)

    assert_equal 123, identity.token_expires_at
    assert_equal 123, identity.expires_at
  end

  class MockAuth < OpenStruct; end
end
