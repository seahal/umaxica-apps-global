# typed: false
# frozen_string_literal: true

class ExternalAuthenticationOrgEntraCeremonyStore
  CEREMONY_TTL = 5.minutes
  CACHE_PREFIX = "external-authentication/org-entra-ceremony".freeze

  Ceremony = Data.define(:surface, :provider, :operation, :connection_public_id, :state, :nonce, :code_verifier, :return_target)

  def initialize(cache: Rails.cache, clock: -> { Time.current })
    @cache = cache
    @clock = clock
  end

  def issue!(surface:, provider:, operation:, connection_public_id:, state:, nonce:, code_verifier:, return_target:)
    raise ArgumentError, "ceremony contract is invalid" unless surface == "org" && provider == "entra" && operation == "login"

    reference = SecureRandom.urlsafe_base64(32)
    OperatorOauthCallbackState.issue!(state: state, provider: "entra", intent: "login", now: clock.call)
    cache.write(
      cache_key(reference),
      {
        "connection_public_id" => connection_public_id,
        "surface" => surface,
        "provider" => provider,
        "operation" => operation,
        "state" => state,
        "nonce" => nonce,
        "code_verifier" => code_verifier,
        "return_target" => return_target,
      },
      expires_in: CEREMONY_TTL,
    )
    reference
  end

  def consume!(reference:, callback_state:, surface:, provider:, operation:)
    payload = cache.read(cache_key(reference))
    cache.delete(cache_key(reference))
    return nil if payload.nil?

    expected_state = payload.fetch("state")
    consumed = OperatorOauthCallbackState.consume!(state: expected_state, provider: "entra", now: clock.call)
    return nil unless consumed &&
      payload.slice("surface", "provider", "operation") == {
        "surface" => surface,
        "provider" => provider,
        "operation" => operation,
      } &&
      secure_equal?(expected_state, callback_state)

    Ceremony.new(
      surface: payload.fetch("surface"),
      provider: payload.fetch("provider"),
      operation: payload.fetch("operation"),
      connection_public_id: payload.fetch("connection_public_id"),
      state: expected_state,
      nonce: payload.fetch("nonce"),
      code_verifier: payload.fetch("code_verifier"),
      return_target: payload.fetch("return_target"),
    )
  end

  private

  attr_reader :cache, :clock

  def cache_key(reference)
    "#{CACHE_PREFIX}/#{reference}"
  end

  def secure_equal?(left, right)
    return false if left.blank? || right.blank? || left.bytesize != right.bytesize

    ActiveSupport::SecurityUtils.secure_compare(left, right)
  end
end
