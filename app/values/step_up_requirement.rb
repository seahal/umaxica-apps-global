# typed: false
# frozen_string_literal: true

class StepUpRequirement
  SUPPORTED_AALS = %i(aal1 aal2 aal3).freeze
  DEFAULT_AAL = :aal2
  DEFAULT_ALLOWED_METHODS = %i(totp passkey).freeze
  DEFAULT_TTL = 15.minutes

  attr_reader :required_aal, :allowed_methods, :scope, :session_binding,
              :token_binding, :ttl, :purpose, :audience, :require_session_binding

  def self.build(value = nil, **attributes)
    return value if value.is_a?(self)

    if value.is_a?(Hash)
      new(**value.symbolize_keys.merge(attributes))
    else
      new(scope: value, **attributes)
    end
  end

  def initialize(required_aal: DEFAULT_AAL, allowed_methods: DEFAULT_ALLOWED_METHODS, scope: nil,
                 session_binding: nil, token_binding: nil, ttl: DEFAULT_TTL,
                 purpose: nil, audience: nil, require_session_binding: false)
    @required_aal = normalize_aal(required_aal)
    allowed = Array(allowed_methods).filter_map { |method| normalize_method(method) }
    allowed.uniq!
    @allowed_methods = allowed.freeze
    @scope = scope.to_s.presence
    @session_binding = session_binding.to_s.presence
    @token_binding = token_binding.to_s.presence
    @ttl = ttl
    @purpose = purpose.to_s.presence
    @audience = audience.to_s.presence
    @require_session_binding = require_session_binding
  end

  def aal_supported?
    SUPPORTED_AALS.include?(required_aal) && required_aal != :aal3
  end

  def method_allowed?(method)
    method = normalize_method(method)
    method.present? && allowed_methods.include?(method)
  end

  private

  def normalize_aal(value)
    value.to_s.presence&.downcase&.to_sym || DEFAULT_AAL
  end

  def normalize_method(value)
    value.to_s.presence&.downcase&.to_sym
  end
end
