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

      # Configuration for testing

      class << self
        def test_mode
          Thread.current[:turnstile_verifier_test_mode]
        end

        def test_mode=(value)
          Thread.current[:turnstile_verifier_test_mode] = value
        end

        def test_response
          Thread.current[:turnstile_verifier_test_response]
        end

        def test_response=(value)
          Thread.current[:turnstile_verifier_test_response] = value
        end

        def test_mode?
          test_mode == true
        end
      end

      def self.verify(token:, remote_ip:, secret_key: nil, mode: nil)
        new(token: token, remote_ip: remote_ip, secret_key: secret_key, mode: mode).verify
      end

      def initialize(token:, remote_ip:, secret_key: nil, mode: nil)
        @token = token
        @remote_ip = remote_ip
        @mode = mode
        @secret_key = secret_key || resolve_secret_key
      end

      def verify
        # Check test mode
        if self.class.test_mode? || self.class.test_response
          return self.class.test_response || { "success" => true }
        end

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
