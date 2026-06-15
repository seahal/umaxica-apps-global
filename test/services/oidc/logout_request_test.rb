# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcLogoutRequestTest < ActiveSupport::TestCase
  test "round trips signed logout request" do
    token = OidcLogoutRequest.issue(client_id: "base-rails-rp", ri: "jp")

    payload = OidcLogoutRequest.verify(token)

    assert_equal "base-rails-rp", payload[:client_id]
    assert_equal "jp", payload[:ri]
  end

  test "rejects tampered logout request" do
    token = OidcLogoutRequest.issue(client_id: "base-rails-rp", ri: "jp")

    assert_nil OidcLogoutRequest.verify("#{token}x")
  end

  test "normalizes unsupported region to default" do
    token = OidcLogoutRequest.issue(client_id: "base-rails-rp", ri: "evil")

    assert_equal "jp", OidcLogoutRequest.verify(token)[:ri]
  end

  # Regression: signed logout requests must be one-shot. Rails.cache is
  # :null_store in the test env, so we inject a real cache for replay
  # tracking; with that in place a second verify() of the same token
  # returns nil. See S-3.
  test "returns nil on the second verify of the same token (replay protection)" do
    OidcLogoutRequest.replay_store = ActiveSupport::Cache::MemoryStore.new
    token = OidcLogoutRequest.issue(client_id: "base-rails-rp", ri: "jp")

    first = OidcLogoutRequest.verify(token)
    second = OidcLogoutRequest.verify(token)

    assert_not_nil first
    assert_equal "base-rails-rp", first[:client_id]
    assert_nil second, "Re-presenting the same signed logout request must be rejected"
  ensure
    OidcLogoutRequest.replay_store = nil
  end

  test "includes a non-empty jti claim on every issued token" do
    OidcLogoutRequest.replay_store = ActiveSupport::Cache::MemoryStore.new
    token_a = OidcLogoutRequest.issue(client_id: "base-rails-rp", ri: "jp")
    token_b = OidcLogoutRequest.issue(client_id: "base-rails-rp", ri: "jp")

    payload_a = OidcLogoutRequest.verify(token_a)
    payload_b = OidcLogoutRequest.verify(token_b)

    assert_predicate payload_a[:jti], :present?
    assert_predicate payload_b[:jti], :present?
    assert_not_equal payload_a[:jti], payload_b[:jti]
  ensure
    OidcLogoutRequest.replay_store = nil
  end

  # If the replay-tracking store is unreachable we treat the token as
  # already consumed (fail closed) rather than allow replay. See S-3.
  class RaisingReplayStore
    def exist?(_key)
      raise StandardError, "boom"
    end

    def write(*)
      nil
    end
  end

  test "fail-closed when the replay store raises on read" do
    OidcLogoutRequest.replay_store = RaisingReplayStore.new
    token = OidcLogoutRequest.issue(client_id: "base-rails-rp", ri: "jp")

    assert_nil OidcLogoutRequest.verify(token),
               "verify must return nil (fail-closed) when replay tracking is unreachable"
  ensure
    OidcLogoutRequest.replay_store = nil
  end
end
