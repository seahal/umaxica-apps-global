# typed: false
# frozen_string_literal: true

require "base64"

module SignWebauthn
  extend ActiveSupport::Concern

  CHALLENGE_SESSION_KEY = :passkey_challenges
  CHALLENGE_TTL = 10.minutes
  MAX_CHALLENGES_PER_SESSION = 5

  class ChallengeError < StandardError; end

  class ChallengeNotFoundError < ChallengeError; end

  class ChallengeExpiredError < ChallengeError; end

  class ChallengePurposeMismatchError < ChallengeError; end

  class OriginValidationError < StandardError; end

  # Returns the Relying Party ID for WebAuthn.
  # Prefer surface-specific environment configuration so deployments behind
  # proxies can use the public browser hostname instead of the internal host.
  def webauthn_rp_id
    configured_webauthn_value("RP_ID") || request.host
  end

  # Returns the expected origin for WebAuthn verification.
  # Prefer surface-specific environment configuration so verification matches
  # the browser's public origin even when Rails sees an internal scheme/host.
  def webauthn_origin
    configured_webauthn_value("ORIGIN") || request.base_url
  end

  # Returns a per-request WebAuthn::RelyingParty instance.
  # This avoids mutating global WebAuthn.configuration state.
  def webauthn_relying_party
    WebAuthn::RelyingParty.new(
      allowed_origins: [webauthn_origin],
      id: webauthn_rp_id,
    )
  end

  # Validates that the current request origin is in TRUSTED_ORIGINS.
  # Raises OriginValidationError if not trusted.
  def validate_webauthn_origin!
    origin = webauthn_origin
    unless trusted_webauthn_origin?(origin)
      raise OriginValidationError, I18n.t("errors.webauthn.origin_not_trusted", origin: origin)
    end

    origin
  end

  def trusted_webauthn_origin?(origin)
    return true if configured_webauthn_value("ORIGIN") == origin
    return true if ::Webauthn.trusted_origins.include?(origin)

    uri = URI.parse(origin)
    ::Webauthn.trusted_origins.any? do |trusted_origin|
      trusted_uri = URI.parse(trusted_origin)
      trusted_uri.scheme == uri.scheme && trusted_uri.host == uri.host
    rescue URI::InvalidURIError
      false
    end
  rescue URI::InvalidURIError
    false
  end

  def configured_webauthn_value(suffix)
    env_keys = []
    surface_key = webauthn_surface_env_key
    env_keys << "WEBAUTHN_#{surface_key}_#{suffix}" if surface_key.present?
    env_keys << "WEBAUTHN_#{suffix}"

    env_keys.each do |key|
      value = ENV.fetch(key).to_s.strip
      next if value.blank?

      return normalize_webauthn_config_value(value, suffix)
    end

    nil
  end

  def webauthn_surface_env_key
    case self.class.name
    when /\ASign::App::/
      "APP"
    when /\ASign::Com::/
      "COM"
    when /\ASign::Org::/
      "ORG"
    end
  end

  def normalize_webauthn_config_value(value, suffix)
    return URI.parse(value).host if suffix == "RP_ID" && value.match?(%r{\Ahttps?://}i)

    value
  rescue URI::InvalidURIError
    value
  end

  # Creates a WebAuthn registration challenge for the given user/staff.
  #
  # @param resource [Client, Operator] The user or staff to create credential for
  # @param exclude_credentials [Array<Hash>] Existing credentials to exclude
  # @return [Array<String, WebAuthn::PublicKeyCredential::CreationOptions>]
  #   Returns [challenge_id, options]
  def create_registration_challenge(resource:, exclude_credentials: [])
    validate_webauthn_origin!

    # Build exclude list from existing passkeys
    exclude_list =
      exclude_credentials.pluck(:id)

    options = WebAuthn::Credential.options_for_create(
      user: {
        id: resource.id.to_s.b,
        name: resource_display_name(resource),
        display_name: resource_display_name(resource),
      },
      exclude: exclude_list,
      authenticator_selection: {
        resident_key: "discouraged",
        user_verification: "preferred",
      },
      attestation: "none",
      rp: { id: webauthn_rp_id },
    )

    challenge_id = store_challenge!(
      challenge: options.challenge,
      purpose: :registration,
    )

    [challenge_id, normalize_webauthn_options_for_json(options)]
  end

  # Creates a WebAuthn authentication challenge.
  #
  # @param allow_credentials [Array<Hash>] Credentials to allow (with :id key as Base64URL)
  # @return [Array<String, WebAuthn::PublicKeyCredential::RequestOptions>]
  #   Returns [challenge_id, options]
  def create_authentication_challenge(allow_credentials:, user_verification: "preferred")
    validate_webauthn_origin!

    allow_list =
      allow_credentials.pluck(:id)

    options = WebAuthn::Credential.options_for_get(
      allow: allow_list,
      user_verification: user_verification,
      rp_id: webauthn_rp_id,
    )

    challenge_id = store_challenge!(
      challenge: options.challenge,
      purpose: :authentication,
    )

    [challenge_id, normalize_webauthn_options_for_json(options)]
  end

  # Executes a block with the challenge, then deletes it.
  # This ensures one-time use of challenges.
  #
  # @param challenge_id [String] The challenge ID from options response
  # @param purpose [Symbol] Expected purpose (:registration or :authentication)
  # @yield [challenge] Block that receives the challenge string
  # @return [Object] Result of the block
  def with_challenge(challenge_id, purpose:)
    challenge = fetch_and_delete_challenge!(challenge_id, purpose: purpose)
    yield(challenge)
  end

  # Fetches challenge without deleting (for inspection)
  def peek_challenge(challenge_id)
    challenges = session[CHALLENGE_SESSION_KEY] || {}
    challenges[challenge_id]
  end

  # Idempotently removes a challenge from the session. Intended for
  # `ensure` blocks where the caller wants to guarantee a challenge does
  # not survive any code path (success, validation failure, or
  # unexpected exception before `fetch_and_delete_challenge!` ran).
  # Safe to call when the challenge is already gone.
  def force_delete_challenge!(challenge_id)
    return if challenge_id.blank?

    challenges = session[CHALLENGE_SESSION_KEY]
    return unless challenges.is_a?(Hash) && challenges.key?(challenge_id)

    challenges.delete(challenge_id)
    session[CHALLENGE_SESSION_KEY] = challenges
  end

  private

  # Stores a challenge in session and returns its ID.
  #
  # @param challenge [String] The WebAuthn challenge (Base64URL encoded)
  # @param purpose [Symbol] :registration or :authentication
  # @return [String] The generated challenge ID
  def store_challenge!(challenge:, purpose:)
    session[CHALLENGE_SESSION_KEY] ||= {}
    challenges = session[CHALLENGE_SESSION_KEY]

    # Cleanup expired challenges and enforce limit
    cleanup_expired_challenges!(challenges)
    enforce_challenge_limit!(challenges)

    challenge_id = SecureRandom.urlsafe_base64(16)

    challenges[challenge_id] = {
      "challenge" => challenge,
      "purpose" => purpose.to_s,
      "expires_at" => (Time.current + CHALLENGE_TTL).to_i,
    }

    session[CHALLENGE_SESSION_KEY] = challenges
    challenge_id
  end

  # Fetches and deletes a challenge from session.
  #
  # @param challenge_id [String] The challenge ID
  # @param purpose [Symbol] Expected purpose
  # @return [String] The challenge string
  # @raise [ChallengeNotFoundError] if challenge not found
  # @raise [ChallengeExpiredError] if challenge expired
  # @raise [ChallengePurposeMismatchError] if purpose doesn't match
  def fetch_and_delete_challenge!(challenge_id, purpose:)
    challenges = session[CHALLENGE_SESSION_KEY] || {}
    data = challenges.delete(challenge_id)
    session[CHALLENGE_SESSION_KEY] = challenges

    raise ChallengeNotFoundError, "Challenge not found" unless data

    if Time.current.to_i > data["expires_at"].to_i
      raise ChallengeExpiredError, "Challenge has expired"
    end

    if data["purpose"] != purpose.to_s
      raise ChallengePurposeMismatchError,
            "Purpose mismatch: expected #{purpose}, got #{data["purpose"]}"
    end

    data["challenge"]
  end

  # Removes expired challenges from the hash.
  def cleanup_expired_challenges!(challenges)
    now = Time.current.to_i
    challenges.delete_if { |_, data| data["expires_at"].to_i < now }
  end

  # Removes oldest challenges if limit exceeded.
  def enforce_challenge_limit!(challenges)
    return if challenges.size < MAX_CHALLENGES_PER_SESSION

    # Sort by expires_at and remove oldest
    sorted = challenges.sort_by { |_, data| data["expires_at"].to_i }
    oldest_id, = sorted.first
    challenges.delete(oldest_id)
  end

  # Returns a display name for the resource.
  def resource_display_name(resource)
    if resource.respond_to?(:client_emails) && resource.client_emails.any?
      resource.client_emails.first.address
    elsif resource.respond_to?(:staff_emails) && resource.staff_emails.any?
      resource.staff_emails.first.address
    elsif resource.respond_to?(:public_id)
      resource.public_id
    else
      resource.id.to_s
    end
  end

  def normalize_webauthn_options_for_json(options)
    data = options.respond_to?(:as_json) ? options.as_json : options
    normalized = data.deep_stringify_keys

    source_challenge =
      if options.respond_to?(:challenge)
        options.challenge
      else
        normalized["challenge"]
      end
    normalized["challenge"] = normalize_webauthn_id(source_challenge)

    if normalized["user"].is_a?(Hash)
      source_user_id =
        if options.respond_to?(:user) && options.user.respond_to?(:id)
          options.user.id
        else
          normalized["user"]["id"]
        end
      # User IDs from the WebAuthn gem are raw bytes, not Base64URL encoded.
      # Always force-encode to avoid passing numeric strings (e.g. "980190962")
      # that match Base64URL character set but produce invalid padding in atob().
      normalized["user"]["id"] = Base64.urlsafe_encode64(source_user_id.to_s.b, padding: false)
    end

    normalize_credential_list_ids!(normalized, "excludeCredentials")
    normalize_credential_list_ids!(normalized, "allowCredentials")

    normalized
  end

  def normalize_credential_list_ids!(data, key)
    list = data[key] || data[key.underscore]
    return if list.nil?
    return unless list.is_a?(Array)

    normalized_list =
      list.map do |credential|
        next credential unless credential.is_a?(Hash)

        credential.merge("id" => normalize_webauthn_id(credential["id"]))
      end

    if data.key?(key)
      data[key] = normalized_list
    else
      data[key.underscore] = normalized_list
    end
  end

  def normalize_webauthn_id(value)
    return value if value.nil?

    if value.is_a?(String)
      return value if value.match?(/\A[A-Za-z0-9_-]+\z/)

      return Base64.urlsafe_encode64(value.b, padding: false)
    end
    return Base64.urlsafe_encode64(value.pack("C*"), padding: false) if value.is_a?(Array)
    return Base64.urlsafe_encode64(value.to_s.b, padding: false) if value.is_a?(Integer)

    value
  end
end
