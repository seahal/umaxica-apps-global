# typed: false
# frozen_string_literal: true

module AuthorizationTokenClaims
  module_function

  def build(resource:, session_id: nil, session_public_id: nil, oidc_sid: nil, oidc_jti: nil, resource_type:,
            issued_at:, access_token_ttl:, expires_at: nil, preferences: nil, scopes: nil, acr: nil, amr: nil,
            dpop_jkt: nil, issuer: nil, audiences: nil, subject: nil, auth_time: nil, step_up_until: nil)
    sid = oidc_sid.presence || session_public_id || session_id
    issued_at_seconds = timestamp_value(issued_at)
    expires_at_seconds = timestamp_value(expires_at || (issued_at + access_token_ttl))
    token_type = AuthenticationJwtConfiguration.token_type(resource_type)
    scopes_value = scopes || resolve_scopes(resource_type, resource)

    payload = {
      "iat" => issued_at_seconds,
      "exp" => expires_at_seconds,
      "jti" => oidc_jti.presence || JitSecurityJwtJtiGenerator.generate,
      "sub" => subject.presence || resource.id,
      "act" => resource_type,
      "typ" => token_type,
      "iss" => issuer.presence || AuthenticationJwtConfiguration.issuer(resource_type),
      "aud" => audiences.presence || AuthenticationJwtConfiguration.audiences(resource_type),
      "scp" => scopes_value,
      "acr" => normalize_acr(acr),
    }
    payload["amr"] = Array(amr) if amr.present?
    payload["sid"] = sid if sid.present?
    payload["auth_time"] = timestamp_value(auth_time) if auth_time.present?
    payload["step_up_until"] = timestamp_value(step_up_until) if step_up_until.present?
    payload["prf"] = preferences if preferences.is_a?(Hash) && preferences.present?
    payload["cnf"] = { "jkt" => dpop_jkt } if dpop_jkt.present?
    payload
  end

  def normalize_acr(acr)
    return "aal1" if acr.blank?

    acr.to_s.downcase
  end

  def subject(payload)
    payload&.dig("sub")
  end

  def actor(payload)
    payload&.dig("act")
  end

  def session_id(payload)
    payload&.dig("sid")
  end

  def jti(payload)
    payload&.dig("jti")
  end

  def preferences(payload)
    payload&.dig("prf")
  end

  def scopes(payload)
    payload&.dig("scp") || []
  end

  def audiences(payload)
    payload&.dig("aud") || []
  end

  def timestamp_value(value)
    if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
      return Integer(value.strftime("%s"), 10)
    end

    return value if value.is_a?(Integer)
    return Integer(value, 10) if value.is_a?(Numeric)

    Integer(value.to_s, 10)
  end
  private_class_method :timestamp_value

  # Returns default scopes based on resource type
  # @param resource_type [String] 'client', 'operator', or 'visitor'
  # @param resource [AuthorizationClient/AuthorizationOperator/AuthorizationVisitor] the authenticated resource
  # @return [Array<String>] list of scopes
  def resolve_scopes(resource_type, _resource)
    base_scopes = ["authenticated", "domain:#{resource_type}"]

    case resource_type.to_s
    when "client", "visitor"
      base_scopes + ["read:self", "write:self"]
    when "operator"
      base_scopes + ["read:org", "write:org"]
    else
      base_scopes
    end
  end
  private_class_method :resolve_scopes
end
