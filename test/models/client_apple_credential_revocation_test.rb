# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientAppleCredentialRevocationTest < ActiveSupport::TestCase
  fixtures :client_statuses

  test "encrypts the refresh token and clears it after idempotent completion" do
    request = create_request(refresh_token: "refresh-token")

    stored_value = ClientAppleCredentialRevocation.connection.select_value(
      ClientAppleCredentialRevocation.where(id: request.id).select(:refresh_token).to_sql,
    )

    assert_not_includes stored_value, "refresh-token"
    request.complete!(now: Time.utc(2026, 7, 24, 12, 0, 0))

    assert_equal "completed", request.status
    assert_equal "", request.refresh_token
    assert_predicate request.completed_at, :present?
  end

  test "uses bounded exponential retries then crypto-shreds the token" do
    request = create_request(refresh_token: "refresh-token")
    now = Time.utc(2026, 7, 24, 12, 0, 0)

    assert_equal :retrying, request.retry_or_expire!(code: "provider_unavailable", now: now)
    assert_equal 1, request.retry_count
    assert_equal now + 2.minutes, request.next_retry_at

    request.update!(retry_count: ClientAppleCredentialRevocation::MAXIMUM_RETRIES - 1)

    assert_equal :expired, request.retry_or_expire!(code: "provider_unavailable", now: now)
    assert_equal "expired", request.status
    assert_equal "", request.refresh_token
  end

  test "records an unavailable credential without scheduling a provider call" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "rev_#{SecureRandom.hex(8)}")
    now = Time.utc(2026, 7, 24, 12, 0, 0)

    request = ClientAppleCredentialRevocation.create_for!(
      client: client,
      refresh_token: "",
      reason: "unlink",
      now: now,
    )

    assert_equal "expired", request.status
    assert_equal "credential_unavailable", request.last_failure_code
    assert_not_predicate request, :dispatchable?
    assert_equal now, request.completed_at
  end

  private

  def create_request(refresh_token:)
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "rev_#{SecureRandom.hex(8)}")
    ClientAppleCredentialRevocation.create!(
      client: client,
      refresh_token: refresh_token,
      reason: "unlink",
    )
  end
end
