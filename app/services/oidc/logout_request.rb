# typed: false
# frozen_string_literal: true

module Oidc
  # Signed, one-shot logout-request token issued by the IdP to the RP and
  # presented back at `GET /oidc/logout`. Two layered protections:
  #
  #   1. `verifier.generate / verified` ensures the token is signed and
  #      not expired (TTL = 2 minutes).
  #   2. A unique `jti` claim is consumed on first successful `verify`.
  #      Re-presenting the same token returns nil so the controller can
  #      respond with `invalid_request`. This blocks GET-replay vectors
  #      where the same logout link is followed twice (browser history,
  #      copy-pasted URL, link prefetcher) and incidentally raises the
  #      bar against CSRF-style attempts to trick a user into clicking
  #      a stolen-but-still-fresh logout link.
  module LogoutRequest
    PURPOSE = "oidc_logout_request"
    TTL = 2.minutes
    ALLOWED_RI = %w(jp us).freeze
    JTI_BYTES = 16
    REPLAY_CACHE_PREFIX = "oidc:logout_request:consumed:"
    # Track consumed jtis slightly longer than the token TTL so a token
    # that expires in-flight cannot be replayed against a process whose
    # clock skew gives it a few extra seconds.
    REPLAY_TRACKING_TTL = TTL + 30.seconds

    class << self
      # Replay tracking store. Defaults to Rails.cache (Solid Cache in
      # production). Tests may inject a real store because Rails.cache
      # is `:null_store` in the test environment.
      attr_writer :replay_store

      def replay_store
        @replay_store ||= Rails.cache
      end

      def issue(client_id:, ri:)
        verifier.generate(
          {
            "client_id" => client_id.to_s,
            "ri" => normalize_ri(ri),
            "jti" => SecureRandom.hex(JTI_BYTES),
          },
          purpose: PURPOSE,
          expires_in: TTL,
        )
      end

      # Returns the parsed payload on the first successful verification
      # and `nil` thereafter for the same token. A `nil` return means
      # either a signature/TTL failure or a replay.
      def verify(token)
        payload = verifier.verified(token.to_s, purpose: PURPOSE)
        return unless payload.is_a?(Hash)

        client_id = payload["client_id"].to_s
        return if client_id.blank?

        jti = payload["jti"].to_s
        return if jti.blank?
        return if jti_consumed?(jti)

        consume_jti!(jti)

        {
          client_id: client_id,
          ri: normalize_ri(payload["ri"]),
          jti: jti,
        }
      end

      private

      def normalize_ri(value)
        normalized = value.to_s.downcase
        ALLOWED_RI.include?(normalized) ? normalized : "jp"
      end

      def verifier
        Rails.application.message_verifier(:oidc_logout_request)
      end

      def jti_consumed?(jti)
        replay_store.exist?(replay_cache_key(jti))
      rescue StandardError => e
        # Fail closed: if the store is unreachable we treat the token as
        # already consumed rather than risk allowing replay. Operators
        # see the failure via application logs.
        Rails.logger.info(LogEvent.format(
          "oidc.logout_request.replay_store_unavailable",
          op: "exist?",
          error_class: e.class.name,
          error_message: e.message,
        ))
        true
      end

      def consume_jti!(jti)
        replay_store.write(replay_cache_key(jti), true, expires_in: REPLAY_TRACKING_TTL)
      rescue StandardError => e
        Rails.logger.info(LogEvent.format(
          "oidc.logout_request.replay_store_unavailable",
          op: "write",
          error_class: e.class.name,
          error_message: e.message,
        ))
        false
      end

      def replay_cache_key(jti)
        "#{REPLAY_CACHE_PREFIX}#{jti}"
      end
    end
  end
end
