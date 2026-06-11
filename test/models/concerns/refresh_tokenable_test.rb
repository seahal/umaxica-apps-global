# typed: false
# frozen_string_literal: true

require "test_helper"

class RefreshTokenableTest < ActiveSupport::TestCase
  setup do
    ClientStatus.ensure_defaults!
    ClientTokenStatus.ensure_defaults!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::NOTHING)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)

    @user = Client.create!(
      public_id: "u_#{SecureRandom.hex(8)}",
      status_id: ClientStatus::ACTIVE,
      created_at: 1.day.ago,
      updated_at: 1.day.ago,
    )
  end

  test "create! seeds refresh metadata and device session" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    assert_predicate token.refresh_token_family_id, :present?
    assert_equal 0, token.refresh_token_generation
    assert_predicate token.device_session_id, :present?
    assert_predicate token.device_session, :present?
  end

  test "refresh_token= stores a digest and clears it when blank" do
    token = ClientToken.new(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    token.refresh_token = "verifier-1"

    assert_predicate token.refresh_token_digest, :present?

    token.refresh_token = ""

    assert_nil token.refresh_token_digest
  end

  test "expired_refresh? and active? reflect discarding time" do
    token = ClientToken.new(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.define_singleton_method(:discarded_at) { 1.day.from_now }

    assert_not_predicate token, :expired_refresh?
    assert_predicate token, :active?

    token.define_singleton_method(:discarded_at) { 1.minute.ago }

    assert_predicate token, :expired_refresh?
    assert_not_predicate token, :active?
  end
end
