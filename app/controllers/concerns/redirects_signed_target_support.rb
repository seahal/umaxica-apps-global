# typed: false
# frozen_string_literal: true

module RedirectsSignedTargetSupport
  extend ActiveSupport::Concern

  SIGNED_TARGET_SECRET_LENGTH = 32
  SIGNED_TARGET_DIGEST = "SHA256"

  private

  def issue_signed_target_token(payload:, purpose:, salt:, expires_in:)
    signed_target_verifier(salt).generate(payload, purpose: purpose, expires_in: expires_in)
  end

  def verified_signed_target_payload(token, purpose:, salt:, expected_flow:, expected_surface:, session_nonce:)
    token_value = token.to_s
    return nil if token_value.blank?

    expected_flow_value = expected_flow.to_s
    expected_surface_value = expected_surface.to_s
    return nil if expected_flow_value.blank? || expected_surface_value.blank?

    payload = signed_target_verifier(salt).verified(token_value, purpose: purpose)
    return nil unless payload.is_a?(Hash)
    return nil unless signed_target_claims_match?(
      payload,
      expected_flow: expected_flow_value,
      expected_surface: expected_surface_value,
      session_nonce: session_nonce,
    )

    payload
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError
    nil
  end

  def signed_target_claims(flow:, surface:, session_nonce:)
    flow_value = flow.to_s
    surface_value = surface.to_s
    session_nonce_value = session_nonce.to_s
    return nil if flow_value.blank? || surface_value.blank? || session_nonce_value.blank?

    {
      "flow" => flow_value,
      "surface" => surface_value,
      "session_nonce" => session_nonce_value,
    }
  end

  def signed_target_claims_match?(payload, expected_flow:, expected_surface:, session_nonce:)
    return false unless payload["flow"].to_s == expected_flow.to_s
    return false unless payload["surface"].to_s == expected_surface.to_s

    expected_session_nonce = session_nonce.to_s
    return true if expected_session_nonce.blank?

    payload["session_nonce"].to_s == expected_session_nonce
  end

  def signed_target_internal_path(value)
    return nil unless value.is_a?(String)
    return nil if value.blank?
    return nil if value.match?(/[\x00-\x1F\x7F]/)
    return nil if value.match?(/%(?:0[0-9a-f]|1[0-9a-f]|7f)/i)
    return nil if value.match?(/%(?:2f|5c)/i)
    return nil if value.include?("\\")

    uri = URI.parse(value)
    return nil if uri.scheme.present? || uri.host.present?
    return nil if uri.userinfo.present?
    return nil if uri.fragment.present?

    path = uri.path
    return nil if path.blank?
    return nil unless path.start_with?("/")
    return nil if path.start_with?("//")

    uri.query.present? ? "#{path}?#{uri.query}" : path
  rescue URI::InvalidURIError
    nil
  end

  def signed_target_clean_string(value)
    return nil unless value.is_a?(String)
    return nil if value.blank?
    return nil if value.match?(/[\x00-\x1F\x7F]/)
    return nil if value.match?(/%(?:0[0-9a-f]|1[0-9a-f]|7f)/i)
    return nil if value.include?("\\")

    value
  end

  def log_signed_target_rejection(event_name, reason, payload: nil)
    Rails.logger.info(
      JitLogEvent.format(
        event_name,
        reason: reason,
        flow: payload&.dig("flow"),
        surface: payload&.dig("surface"),
        request_host: signed_target_request_attribute(:host),
        request_path: signed_target_request_attribute(:fullpath),
        request_id: signed_target_request_attribute(:request_id),
      ),
    )
  end

  def signed_target_request_attribute(name)
    return nil unless respond_to?(:request, true)
    return nil unless request.respond_to?(name)

    request.public_send(name)
  end

  def signed_target_verifier(salt)
    @signed_target_verifiers ||= {}
    @signed_target_verifiers.fetch(salt) do
      @signed_target_verifiers[salt] =
        ActiveSupport::MessageVerifier.new(
          Rails.application.key_generator.generate_key(salt, SIGNED_TARGET_SECRET_LENGTH),
          digest: SIGNED_TARGET_DIGEST,
          serializer: JSON,
          url_safe: true,
        )
    end
  end
end
