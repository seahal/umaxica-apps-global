# typed: false
# frozen_string_literal: true

require "net/http"
require "uri"

module Turnstile
  extend ActiveSupport::Concern

  VALIDATION_OVERRIDE_RESPONSE = Concurrent::AtomicReference.new

  class << self
    def validation_override_response
      VALIDATION_OVERRIDE_RESPONSE.value
    end

    def validation_override_response=(value)
      VALIDATION_OVERRIDE_RESPONSE.value = value
    end

    alias_method :test_response, :validation_override_response
    alias_method :test_response=, :validation_override_response=
  end

  included do
    attr_accessor :turnstile_response, :turnstile_remote_ip
    attr_writer :turnstile_error_message

    validates_with TurnstileValidator, if: :turnstile_required?
  end

  def require_turnstile(response:, remote_ip:, error_message: nil)
    self.turnstile_response = response
    self.turnstile_remote_ip = remote_ip
    @turnstile_error_message = error_message
    @turnstile_required = true
    @turnstile_result = nil
    self
  end

  def turnstile_valid?
    return true unless turnstile_required?

    turnstile_result["success"]
  end

  def turnstile_required?
    @turnstile_required
  end

  def turnstile_result
    @turnstile_result ||= self.class.verify_turnstile(
      turnstile_response: turnstile_response,
      remote_ip: turnstile_remote_ip,
    )
  end

  def turnstile_error_message
    @turnstile_error_message.presence || I18n.t("turnstile_error")
  end

  private :turnstile_result

  module ClassMethods
    def verify_turnstile(turnstile_response:, remote_ip:)
      return Turnstile.validation_override_response if Turnstile.validation_override_response.present?

      Jit::Security::TurnstileVerifier.verify(
        token: turnstile_response,
        remote_ip: remote_ip,
        mode: :visible,
      )
    end
  end
end
