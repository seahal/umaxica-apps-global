# typed: false
# frozen_string_literal: true

# Rotates refresh tokens using one-time consume semantics.
# Old rows are preserved and replay is detected via rotated_at.
module Sign
  class RefreshTokenService
    def self.call(refresh_token:)
      new(refresh_token).call
    end

    def initialize(refresh_token)
      @refresh_token = refresh_token
    end

    def call
      public_id, verifier = parse_refresh_token!

      result = nil
      ActiveRecord::Base.connected_to(role: :writing) do
        operation = -> { find_token(public_id) }
        token = defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call

        raise InvalidRefreshToken, "token_not_found" unless token
        raise InvalidRefreshToken, "invalid_digest" unless token.refresh_token_digest_matches?(verifier)

        digest = token.class.digest_refresh_token(verifier)
        result = token.class.rotate_refresh!(
          presented_refresh_digest: digest,
          device_id: token.device_id,
          now: Time.current,
        )
      end

      case result[:status]
      when :rotated
        { token: result[:token],
          refresh_token: result[:refresh_token],
          previous_token: result[:previous_token], }
      when :replay
        handle_refresh_token_reuse(result[:token])
        raise InvalidRefreshToken, "refresh_token_reuse_detected"
      else
        raise InvalidRefreshToken, "inactive_token"
      end
    end

    private

    def parse_refresh_token!
      parsed = UserToken.parse_refresh_token(@refresh_token)
      raise InvalidRefreshToken, "invalid_format" unless parsed

      parsed
    end

    def find_token(public_id)
      UserToken.find_by(public_id: public_id) ||
        OperatorToken.find_by(public_id: public_id) ||
        VisitorToken.find_by(public_id: public_id)
    end

    # When reuse is observed (a valid token that no longer matches the
    # stored digest), we treat the event as a compromise and revoke all
    # tokens belonging to the same actor. This is logged
    # without the raw refresh verifier to avoid exposing secrets.
    def handle_refresh_token_reuse(token)
      actor_scope = actor_tokens_scope(token)
      now = Time.current
      actor_scope.find_each do |actor|
        attrs = { lapses_at: now }
        actor.update!(attrs)
      end

      actor_key = actor_identifier_column(token) || :user_id
      Sign::Risk::Emitter.emit(
        "refresh_reuse_detected",
        actor_key => actor_identifier(token),
        :user_token_id => token.public_id,
      )

      Rails.event.notify(
        "authentication.refresh.reuse_detected",
        token_id: token.public_id,
        refresh_token_family_id: token.refresh_token_family_id,
        actor_type: actor_type_label(token),
        actor_id: actor_identifier(token),
      )
    end

    def actor_tokens_scope(token)
      column = actor_identifier_column(token)
      return token.class.where(id: token.id) unless column

      token.class.where(column => token.public_send(column))
    end

    def actor_identifier_column(token)
      return :user_id if token.respond_to?(:user_id) && token.user_id.present?
      return :staff_id if token.respond_to?(:staff_id) && token.staff_id.present?
      return :visitor_id if token.respond_to?(:visitor_id) && token.visitor_id.present?

      nil
    end

    def actor_identifier(token)
      column = actor_identifier_column(token)
      column ? token.public_send(column) : nil
    end

    def actor_type_label(token)
      actor_identifier_column(token)&.to_s&.delete_suffix("_id")
    end
  end
end
