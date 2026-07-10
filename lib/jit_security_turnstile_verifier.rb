# typed: false
# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "jit_security_turnstile_config"

class JitSecurityTurnstileVerifier
  VERIFY_URI = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify").freeze
  TEST_MODE = Concurrent::AtomicReference.new(false)
  TEST_RESPONSE = Concurrent::AtomicReference.new

  class << self
    def test_mode
      return false unless test_override_allowed?

      TEST_MODE.value
    end

    def test_mode=(value)
      assert_test_override_allowed!

      TEST_MODE.value = value
    end

    def test_response
      return nil unless test_override_allowed?

      TEST_RESPONSE.value
    end

    def test_response=(value)
      assert_test_override_allowed!

      TEST_RESPONSE.value = value
    end

    private

    def test_override_allowed?
      defined?(Rails) &&
        Rails.configuration.x.security.try(:allow_turnstile_validation_override) == true
    end

    def assert_test_override_allowed!
      return if test_override_allowed?

      raise RuntimeError, "JitSecurityTurnstileVerifier test override is allowed only in test"
    end
  end

  def self.verify(token:, remote_ip:, secret_key: nil, mode: nil)
    return test_response if test_response.present?
    return { "success" => true } if test_mode

    new(token: token, remote_ip: remote_ip, secret_key: secret_key, mode: mode).verify
  end

  def self.verify_for_ceremony(token:, remote_ip:, ceremony_id:, expected_action:, expected_hostname:, expected_cdata:,
                               secret_key: nil, mode: nil)
    return test_response if test_response.present?
    return { "success" => true } if test_mode

    new(
      token: token,
      remote_ip: remote_ip,
      secret_key: secret_key,
      mode: mode,
      ceremony_id: ceremony_id,
      expected_action: expected_action,
      expected_hostname: expected_hostname,
      expected_cdata: expected_cdata,
    ).verify_for_ceremony
  end

  def initialize(token:, remote_ip:, secret_key: nil, mode: nil, ceremony_id: nil, expected_action: nil,
                 expected_hostname: nil, expected_cdata: nil)
    @token = token
    @remote_ip = remote_ip
    @mode = mode
    @secret_key = secret_key || resolve_secret_key
    @ceremony_id = ceremony_id
    @expected_action = expected_action
    @expected_hostname = expected_hostname
    @expected_cdata = expected_cdata
  end

  def verify
    return failure("missing cf-turnstile-response") if @token.blank?

    if @secret_key.blank?
      log_missing_secret
      return failure("missing turnstile secret")
    end

    response = perform_request
    log_development_response(response)
    response
  rescue StandardError => e
    # Decoupled notification: only if Rails event system exists
    if defined?(Rails) && Rails.respond_to?(:event)
      Rails.logger.info(
        JitLogEvent.format(
          "turnstile.verify.failed", error_class: e.class.name,
                                     error_message: e.message,
        ),
      )
    end
    failure(e.message)
  end

  def verify_for_ceremony
    response = verify
    return response unless response["success"]

    return failure("missing ceremony binding") if @ceremony_id.blank?

    unless binding_matches?(response)
      return failure("turnstile binding mismatch")
    end

    replay_result = consume_replay_token!(response)
    return replay_result if replay_result.is_a?(Hash) && replay_result["success"] == false

    response
  end

  private

  def resolve_secret_key
    case @mode
    when :stealth
      JitSecurityTurnstileConfig.stealth_secret_key
    else
      JitSecurityTurnstileConfig.visible_secret_key
    end
  end

  def perform_request
    response = Net::HTTP.post_form(
      VERIFY_URI,
      {
        "secret" => @secret_key,
        "response" => @token,
        "remoteip" => @remote_ip,
      },
    )
    JSON.parse(response.body)
  end

  def log_development_response(response)
    return unless defined?(Rails) && Rails.env.development? && defined?(Rails.logger) && Rails.logger
    return unless response.is_a?(Hash)

    Rails.logger.warn(
      JitLogEvent.format(
        "turnstile.verify.response",
        mode: @mode || :visible,
        success: response["success"],
        error_codes: response["error-codes"],
        hostname: response["hostname"],
        action: response["action"],
        turnstile_time: response["challenge_ts"],
        cdata_present: response["cdata"].present?,
        secret_key_present: @secret_key.present?,
        token_present: @token.present?,
      ),
    )
  end

  def binding_matches?(response)
    hostname_matches = @expected_hostname.blank? || response["hostname"].to_s == @expected_hostname.to_s
    action_matches = @expected_action.blank? || response["action"].to_s == @expected_action.to_s
    cdata_matches = @expected_cdata.blank? || response["cdata"].to_s == @expected_cdata.to_s

    hostname_matches && action_matches && cdata_matches
  end

  def consume_replay_token!(response)
    return unless defined?(TurnstileReplayStore)

    TurnstileReplayStore.consume!(
      token: @token,
      ceremony_id: @ceremony_id,
      action: response["action"],
      hostname: response["hostname"],
      cdata: response["cdata"],
      expires_at: parse_expires_at(response["challenge_ts"]),
    )
  rescue ActiveRecord::RecordNotUnique
    failure("turnstile replay detected")
  end

  def parse_expires_at(challenge_ts)
    return 15.minutes.from_now if challenge_ts.blank?

    Time.zone.parse(challenge_ts.to_s) + 5.minutes
  rescue ArgumentError, TypeError
    15.minutes.from_now
  end

  def log_missing_secret
    return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

    Rails.logger.warn("[Turnstile] Secret key is missing (mode=#{@mode || :visible}). Verification skipped.")
  end

  def failure(message)
    { "success" => false, "error" => message }
  end
end
