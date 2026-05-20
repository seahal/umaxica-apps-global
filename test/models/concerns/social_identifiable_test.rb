# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialIdentifiableTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  class DummySocial < ApplicationRecord
    self.table_name = "clients"
    include SocialIdentifiable
  end

  test "normalize_provider maps known providers" do
    assert_equal "google", SocialIdentifiable.normalize_provider("google_app")
    assert_equal "microsoft", SocialIdentifiable.normalize_provider("microsoft_graph")
    assert_equal "apple", SocialIdentifiable.normalize_provider("apple")
  end

  test "normalize_provider lowercases unknown providers" do
    assert_equal "custom", SocialIdentifiable.normalize_provider("CUSTOM")
  end

  test "model_for_provider returns model class" do
    assert_equal ClientSocialGoogle, SocialIdentifiable.model_for_provider("google")
    assert_equal ClientSocialApple, SocialIdentifiable.model_for_provider("apple")
  end

  test "model_for_provider raises on unknown provider" do
    error = assert_raises(ArgumentError) { SocialIdentifiable.model_for_provider("unknown") }
    assert_match(/Unknown provider/, error.message)
  end

  test "find_by_uid_with_lock supports lock option" do
    identity = ClientSocialApple.create!(
      user: clients(:one),
      uid: "lock-uid",
      token: "token",
      expires_at: 123,
    )

    found = ClientSocialApple.find_by_uid_with_lock("lock-uid", lock: true)

    assert_equal identity.id, found.id
  end

  test "status_column is required for subclasses" do
    error = assert_raises(NotImplementedError) { DummySocial.status_column }
    assert_match(/Subclass must define status_column/, error.message)
  end

  test "status_class is required for subclasses" do
    error = assert_raises(NotImplementedError) { DummySocial.status_class }
    assert_match(/Subclass must define status_class/, error.message)
  end
end
