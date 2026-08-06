# typed: false
# frozen_string_literal: true

# Environment-driven JWT configuration shared by every auth surface.
#
# Previously lived as a nested module inside `AuthenticationBase`.
# Extracted so the 3,000-line AuthenticationBase concern shrinks toward a single
# responsibility, while existing callers that reference
# `AuthenticationJwtConfiguration` keep working via the
# backward-compatibility alias defined in `AuthenticationBase`.
module AuthenticationJwtConfiguration
  VALID_RESOURCE_TYPES = %w(client operator visitor).freeze

  def self.leeway_seconds
    Integer(ENV["AUTH_JWT_LEEWAY_SECONDS"].presence || "30", 10)
  end

  def self.issuer(resource_type = nil)
    base = ENV.fetch("AUTH_JWT_ISSUER")
    normalized_resource_type = normalize_resource_type(resource_type)
    return base if normalized_resource_type.nil?

    "#{base}:#{normalized_resource_type}"
  end

  # Audience is a resource-type boundary: a visitor token must not validate where
  # an operator token is expected. Falling back to a single shared literal when
  # the environment is unset silently collapses that boundary for every resource
  # type at once, so the missing configuration is named instead. `issuer` above
  # already fails this way.
  def self.audiences(resource_type = nil)
    normalized_resource_type = normalize_resource_type(resource_type)
    resource_key = normalized_resource_type&.upcase
    raw =
      if resource_key.present?
        ENV["AUTH_JWT_#{resource_key}_AUDIENCES"].presence || ENV.fetch("AUTH_JWT_AUDIENCES")
      else
        ENV.fetch("AUTH_JWT_AUDIENCES")
      end
    audiences = raw.split(",").map(&:strip)
    audiences.reject!(&:empty?)
    return audiences if audiences.present?

    raise KeyError, "AUTH_JWT_AUDIENCES (or AUTH_JWT_#{resource_key}_AUDIENCES) is set but contains no audience"
  end

  def self.token_type(resource_type)
    normalized_resource_type = normalize_resource_type(resource_type)
    raise ArgumentError, "unsupported auth resource type: #{resource_type.inspect}" if normalized_resource_type.nil?

    "auth-access-token;#{normalized_resource_type}"
  end

  def self.private_key
    JitSecurityJwtKeyring.private_key_for_active
  end

  def self.public_key
    JitSecurityJwtKeyring.public_key_for_active
  end

  def self.normalize_resource_type(resource_type)
    return nil if resource_type.blank?

    normalized = resource_type.to_s
    return normalized if VALID_RESOURCE_TYPES.include?(normalized)

    nil
  end
  private_class_method :normalize_resource_type
end
