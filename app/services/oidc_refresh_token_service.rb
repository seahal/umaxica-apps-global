# typed: false
# frozen_string_literal: true

class OidcRefreshTokenService
  Result =
    Data.define(:success, :token, :refresh_token, :previous_token, :reason) do
      def success? = success

      def [](key)
        public_send(key)
      end

      def fetch(key)
        value = self[key]
        return value unless value.nil?

        raise KeyError, "key not found: #{key.inspect}"
      end
    end

  def self.call(refresh_token:)
    new(refresh_token).call
  end

  def initialize(refresh_token)
    @refresh_token = refresh_token
  end

  def call
    parsed = parse_refresh_token
    return failure(:invalid_format) unless parsed

    public_id, verifier = parsed
    usage = find_usage(public_id)
    return failure(:token_not_found) unless usage
    return failure(:inactive_token, token: usage) unless usage.active?
    return failure(:invalid_digest, token: usage) unless usage.refresh_token_digest_matches?(verifier)

    result = nil
    owner = connection_owner_for(usage.class)
    owner.connected_to(role: :writing) do
      usage.with_lock do
        return failure(:inactive_token, token: usage) unless usage.active?
        return failure(:invalid_digest, token: usage) unless usage.refresh_token_digest_matches?(verifier)

        previous_token = usage.dup
        refresh_token = usage.rotate_refresh_token!
        touch_oidc_connection!(usage)

        result = success(
          token: usage,
          refresh_token: refresh_token,
          previous_token: previous_token,
        )
      end
    end

    result
  end

  private

  def parse_refresh_token
    ClientToken.parse_refresh_token(@refresh_token)
  end

  def find_usage(public_id)
    ClientTokenUsage.find_by(public_id: public_id) ||
      OperatorTokenUsage.find_by(public_id: public_id) ||
      VisitorTokenUsage.find_by(public_id: public_id)
  end

  def touch_oidc_connection!(usage)
    connection = connection_for(usage)
    return unless connection

    connection.update!(last_used_at: Time.current)
  end

  def connection_for(usage)
    parent = usage.parent_token
    return nil unless parent

    case parent
    when ClientToken
      ClientOidcConnection.find_by(user_id: parent.user_id, client_id: usage.oidc_client_id)
    when OperatorToken
      OperatorOidcConnection.find_by(staff_id: parent.staff_id, client_id: usage.oidc_client_id)
    when VisitorToken
      VisitorOidcConnection.find_by(visitor_id: parent.visitor_id, client_id: usage.oidc_client_id)
    end
  end

  def connection_owner_for(klass)
    owner = klass
    owner = owner.superclass until owner.connection_class? || owner == ApplicationRecord
    owner
  end

  def success(token:, refresh_token:, previous_token:)
    Result.new(
      success: true,
      token: token,
      refresh_token: refresh_token,
      previous_token: previous_token,
      reason: nil,
    )
  end

  def failure(reason, token: nil)
    Result.new(
      success: false,
      token: token,
      refresh_token: nil,
      previous_token: nil,
      reason: reason,
    )
  end
end
