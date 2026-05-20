# typed: false
# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require_relative "turnstile_config"

module Jit
  module Security
    class TurnstileVerifier
      VERIFY_URI = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify").freeze
      TEST_MODE = Concurrent::AtomicReference.new(false)
      TEST_RESPONSE = Concurrent::AtomicReference.new

      class << self
        def test_mode
          TEST_MODE.value
        end

        def test_mode=(value)
          TEST_MODE.value = value
        end

        def test_response
          TEST_RESPONSE.value
        end

        def test_response=(value)
          TEST_RESPONSE.value = value
        end
      end

      def self.verify(token:, remote_ip:, secret_key: nil, mode: nil)
        return test_response if test_response.present?
        return { "success" => true } if test_mode

        new(token: token, remote_ip: remote_ip, secret_key: secret_key, mode: mode).verify
      end

      def initialize(token:, remote_ip:, secret_key: nil, mode: nil)
        @token = token
        @remote_ip = remote_ip
        @mode = mode
        @secret_key = secret_key || resolve_secret_key
      end

      def verify
        return failure("missing cf-turnstile-response") if @token.blank?

        if @secret_key.blank?
          log_missing_secret
          return failure("missing turnstile secret")
        end

        perform_request
      rescue StandardError => e
        # Decoupled notification: only if Rails event system exists
        if defined?(Rails) && Rails.respond_to?(:event)
          Rails.event.notify("turnstile.verify.failed", error_class: e.class.name, error_message: e.message)
        end
        failure(e.message)
      end

      private

      def resolve_secret_key
        case @mode
        when :stealth
          TurnstileConfig.stealth_secret_key
        else
          TurnstileConfig.visible_secret_key
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

      def log_missing_secret
        return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

        Rails.logger.warn("[Turnstile] Secret key is missing (mode=#{@mode || :visible}). Verification skipped.")
      end

      def failure(message)
        { "success" => false, "error" => message }
      end
    end
  end
end
