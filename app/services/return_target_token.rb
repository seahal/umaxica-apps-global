# typed: false
# frozen_string_literal: true

# Signed continuation transport for the public `rt` query parameter.
#
# The token wraps the verified `return_to` destination together with the
# `flow`, `surface`, and `session_nonce` it was issued for. Verification rejects
# any token whose purpose, signature, expiry, flow, surface, or session nonce
# does not match the expectation supplied by the caller, and only returns the
# decoded `return_to` after it passes destination policy.
class ReturnTargetToken
  PURPOSE = :return_target
  DEFAULT_EXPIRES_IN = 15.minutes
  SECRET_LENGTH = 32
  DIGEST = "SHA256"
  HOST_ENV_KEYS = %w(
    ID_SERVICE_URL ID_CORPORATE_URL ID_STAFF_URL
    SIGN_SERVICE_URL SIGN_CORPORATE_URL SIGN_STAFF_URL
    APEX_SERVICE_URL APEX_CORPORATE_URL APEX_STAFF_URL
  ).freeze

  Invalid = Class.new(StandardError)

  class << self
    def issue(return_to:, flow:, surface:, session_nonce:, expires_in: DEFAULT_EXPIRES_IN, request: nil)
      payload = build_payload(
        return_to: return_to,
        flow: flow,
        surface: surface,
        session_nonce: session_nonce,
        request: request,
      )

      verifier.generate(payload, purpose: PURPOSE, expires_in: expires_in)
    end

    def verify!(token, expected_flow:, expected_surface:, session_nonce:, request: nil)
      token_value = token.to_s
      raise invalid("blank_token", request: request) if token_value.blank?

      expected_flow_value = expected_flow.to_s
      expected_surface_value = expected_surface.to_s
      raise invalid("blank_expected_flow", request: request) if expected_flow_value.blank?
      raise invalid("blank_expected_surface", request: request) if expected_surface_value.blank?

      payload =
        begin
          verifier.verified(token_value, purpose: PURPOSE)
        rescue ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError
          nil
        end
      raise invalid("invalid_signature", request: request) unless payload.is_a?(Hash)

      raise invalid("wrong_flow", request: request, payload: payload) if payload["flow"].to_s != expected_flow_value
      raise invalid(
        "wrong_surface", request: request,
                         payload: payload,
      ) if payload["surface"].to_s != expected_surface_value

      expected_session_nonce = session_nonce.to_s
      if expected_session_nonce.present? && payload["session_nonce"].to_s != expected_session_nonce
        raise invalid("wrong_session", request: request, payload: payload)
      end

      return_to = payload["return_to"].to_s
      raise invalid("blank_return_to", request: request, payload: payload) if return_to.blank?

      destination = safe_destination(return_to, request: request)
      raise invalid("blocked_return_to", request: request, payload: payload) if destination.blank?

      payload.merge("return_to" => destination)
    end

    # Convenience wrapper: returns the verified `return_to` path on success or
    # nil on any failure. Callers that want the raise-on-error semantics should
    # use `verify!` directly.
    def verified_return_to(token, expected_flow:, expected_surface:, session_nonce:, request: nil)
      verify!(
        token,
        expected_flow: expected_flow,
        expected_surface: expected_surface,
        session_nonce: session_nonce,
        request: request,
      ).fetch("return_to")
    rescue Invalid
      nil
    end

    private

    def build_payload(return_to:, flow:, surface:, session_nonce:, request:)
      destination = safe_destination(return_to, request: request)
      raise invalid("blank_return_to", request: request) if destination.blank?
      raise invalid("blank_flow", request: request) if flow.to_s.blank?
      raise invalid("blank_surface", request: request) if surface.to_s.blank?
      raise invalid("blank_session_nonce", request: request) if session_nonce.to_s.blank?

      {
        "return_to" => destination,
        "flow" => flow.to_s,
        "surface" => surface.to_s,
        "session_nonce" => session_nonce.to_s,
      }
    end

    def safe_destination(target, request:)
      target = target.to_s
      return nil if target.blank?
      return nil if target.match?(/[[:cntrl:]]/)

      begin
        parsed = URI.parse(target)
      rescue URI::InvalidURIError
        return nil
      end

      return nil if parsed.user.present? || parsed.password.present?
      return nil if parsed.fragment.present?

      if parsed.scheme.present? || parsed.host.present?
        return nil unless allowed_absolute_destination?(parsed, request: request)

        path = parsed.path.presence || "/"
        return nil unless path.start_with?("/")

        query = parsed.query.present? ? "?#{parsed.query}" : ""
        port = (parsed.port && parsed.port != default_port_for(parsed.scheme)) ? ":#{parsed.port}" : ""
        return "#{parsed.scheme}://#{parsed.host.downcase}#{port}#{path}#{query}"
      end

      path = parsed.path.presence || "/"
      return nil unless path.start_with?("/")

      parsed.query.present? ? "#{path}?#{parsed.query}" : path
    end

    def allowed_absolute_destination?(uri, request:)
      return false if uri.host.blank?
      return false unless allowed_scheme?(uri.scheme)

      allowed_hosts(request: request).include?(host_with_optional_port(uri))
    end

    def allowed_scheme?(scheme)
      return false unless %w(http https).include?(scheme)
      return true unless Rails.application.config.force_ssl

      scheme == "https"
    end

    def invalid(reason, request: nil, payload: nil)
      Rails.logger.info(
        LogEvent.format(
          "return_target.rejected",
          reason: reason,
          flow: payload&.dig("flow"),
          surface: payload&.dig("surface"),
          request_host: request_attribute(request, :host),
          request_path: request_attribute(request, :fullpath),
          request_id: request_attribute(request, :request_id),
        ),
      )

      Invalid.new(reason)
    end

    def request_attribute(request, name)
      return nil unless request.respond_to?(name)

      request.public_send(name)
    end

    # rubocop:disable ThreadSafety/ClassInstanceVariable
    def verifier
      @verifier ||= ActiveSupport::MessageVerifier.new(
        verifier_secret,
        digest: DIGEST,
        serializer: JSON,
        url_safe: true,
      )
      # rubocop:enable ThreadSafety/ClassInstanceVariable
    end

    def verifier_secret
      Rails.application.key_generator.generate_key(verifier_salt, SECRET_LENGTH)
    end

    def verifier_salt
      name.demodulize.underscore
    end

    def allowed_hosts(request:)
      request_hosts = [
        request_attribute(request, :host_with_port),
        request_attribute(request, :host),
      ]
      env_hosts = HOST_ENV_KEYS.filter_map { |key| ENV[key] }

      (request_hosts + env_hosts).filter_map { |host| normalized_host_with_optional_port(host) }.uniq
    end

    def normalized_host_with_optional_port(value)
      raw = value.to_s.strip.downcase
      return if raw.blank?

      uri = URI.parse(raw.match?(%r{\Ahttps?://}) ? raw : "//#{raw}")
      return if uri.host.blank?

      if uri.port && uri.port != default_port_for(uri.scheme)
        "#{uri.host}:#{uri.port}"
      else
        uri.host
      end
    rescue URI::InvalidURIError
      nil
    end

    def host_with_optional_port(uri)
      host = uri.host.to_s.downcase
      return host if uri.port.blank? || uri.port == default_port_for(uri.scheme)

      "#{host}:#{uri.port}"
    end

    def default_port_for(scheme)
      (scheme == "https") ? 443 : 80
    end
  end
end
