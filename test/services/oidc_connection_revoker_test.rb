# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class OidcConnectionRevokerTest < ActiveSupport::TestCase
  setup do
    @now = Time.zone.parse("2026-06-24 12:00:00 UTC")
  end

  test "revokes the connection and all active tokens for its client" do
    token1 = revocable_token
    token2 = revocable_token
    connection = FakeConnection.new(client_id: "client-1", tokens: [token1, token2])

    result = OidcConnectionRevoker.new(connection: connection, revoked_at: @now).call

    assert_same connection, result
    assert_equal @now, connection.updated_revoked_at
    assert token1.revoked
    assert token2.revoked
  end

  test "only revokes tokens matching the connection client id" do
    matching_token = revocable_token
    other_token = revocable_token
    connection = FakeConnection.new(
      client_id: "client-1", tokens: [matching_token, other_token],
      filtered_tokens: [matching_token],
    )

    OidcConnectionRevoker.new(connection: connection, revoked_at: @now).call

    assert matching_token.revoked
    assert_not other_token.revoked
  end

  test "succeeds when there are no active tokens" do
    connection = FakeConnection.new(client_id: "client-1", tokens: [])

    result = OidcConnectionRevoker.new(connection: connection, revoked_at: @now).call

    assert_same connection, result
    assert_equal @now, connection.updated_revoked_at
  end

  private

  def revocable_token
    RevocableToken.new
  end

  class FakeConnection
    attr_reader :client_id, :updated_revoked_at

    def initialize(client_id:, tokens:, filtered_tokens: nil)
      @client_id = client_id
      @active_tokens = FakeTokenScope.new(tokens, filtered_tokens || tokens)
      @updated_revoked_at = nil
      @klass = FakeConnectionClass.new
    end

    def class
      @klass
    end

    def active_tokens
      @active_tokens
    end

    def update!(attrs)
      @updated_revoked_at = attrs[:revoked_at]
      true
    end
  end

  class FakeConnectionClass
    def transaction
      yield
    end
  end

  class FakeTokenScope
    def initialize(all_tokens, filtered_tokens)
      @all_tokens = all_tokens
      @filtered_tokens = filtered_tokens
    end

    def where(_hash)
      FakeTokenScope.new(@filtered_tokens, @filtered_tokens)
    end

    def find_each
      @all_tokens.each { |token| yield token }
    end
  end

  class RevocableToken
    attr_reader :revoked

    def initialize
      @revoked = false
    end

    def revoke!
      @revoked = true
      true
    end
  end
end
