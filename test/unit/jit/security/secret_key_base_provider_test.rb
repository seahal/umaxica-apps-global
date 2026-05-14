# typed: false
# frozen_string_literal: true

require "test_helper"
require "jit/security/secret_key_base_provider"

module Jit
  module Security
    class SecretKeyBaseProviderTest < ActiveSupport::TestCase
      def with_env(overrides)
        saved = {}
        overrides.each do |key, value|
          saved[key] = ENV[key]
          value.nil? ? ENV.delete(key) : ENV[key] = value
        end
        yield
      ensure
        saved.each do |key, value|
          value.nil? ? ENV.delete(key) : ENV[key] = value
        end
      end

      # --- use_secrets_manager? ---

      test "use_secrets_manager? returns false in test env" do
        with_env("SECRET_KEY_BASE_SECRET_ID" => "arn:aws:secretsmanager:ap-northeast-1:123:secret:test") do
          assert_not_predicate SecretKeyBaseProvider, :use_secrets_manager?
        end
      end

      # --- fetch_from_local ---

      test "fetch_from_local returns ENV SECRET_KEY_BASE as current" do
        with_env("SECRET_KEY_BASE" => "env-key", "SECRET_KEY_BASE_PREVIOUS" => nil) do
          result = SecretKeyBaseProvider.fetch_from_local

          assert_equal "env-key", result[:current]
          assert_equal [], result[:previous]
        end
      end

      test "fetch_from_local parses JSON array for previous keys" do
        with_env(
          "SECRET_KEY_BASE" => "current-key",
          "SECRET_KEY_BASE_PREVIOUS" => '["old-key-1", "old-key-2"]',
        ) do
          result = SecretKeyBaseProvider.fetch_from_local

          assert_equal "current-key", result[:current]
          assert_equal ["old-key-1", "old-key-2"], result[:previous]
        end
      end

      test "fetch_from_local treats non-JSON previous as single key" do
        with_env(
          "SECRET_KEY_BASE" => "current-key",
          "SECRET_KEY_BASE_PREVIOUS" => "plain-old-key",
        ) do
          result = SecretKeyBaseProvider.fetch_from_local

          assert_equal ["plain-old-key"], result[:previous]
        end
      end

      test "fetch_from_local returns empty previous when env not set" do
        with_env("SECRET_KEY_BASE" => "current-key", "SECRET_KEY_BASE_PREVIOUS" => nil) do
          result = SecretKeyBaseProvider.fetch_from_local

          assert_equal [], result[:previous]
        end
      end

      # --- parse_local_previous ---

      test "parse_local_previous returns empty array for blank" do
        with_env("SECRET_KEY_BASE_PREVIOUS" => nil) do
          assert_equal [], SecretKeyBaseProvider.parse_local_previous
        end
      end

      test "parse_local_previous returns empty array for empty string" do
        with_env("SECRET_KEY_BASE_PREVIOUS" => "") do
          assert_equal [], SecretKeyBaseProvider.parse_local_previous
        end
      end

      # --- fetch_from_secrets_manager (mocked) ---

      test "fetch_from_secrets_manager parses valid secret" do
        mock_response = Minitest::Mock.new
        mock_response.expect(:secret_string, '{"current": "sm-key", "previous": ["sm-old-1", "sm-old-2"]}')

        mock_client = Minitest::Mock.new
        mock_client.expect(:get_secret_value, mock_response, [], secret_id: "test-secret")

        with_env("SECRET_KEY_BASE_SECRET_ID" => "test-secret", "AWS_REGION" => "ap-northeast-1") do
          require "aws-sdk-secretsmanager"
          Aws::SecretsManager::Client.stub(:new, mock_client) do
            result = SecretKeyBaseProvider.fetch_from_secrets_manager

            assert_equal "sm-key", result[:current]
            assert_equal ["sm-old-1", "sm-old-2"], result[:previous]
          end
        end

        mock_client.verify
        mock_response.verify
      end

      test "fetch_from_secrets_manager handles missing previous key" do
        mock_response = Minitest::Mock.new
        mock_response.expect(:secret_string, '{"current": "sm-key"}')

        mock_client = Minitest::Mock.new
        mock_client.expect(:get_secret_value, mock_response, [], secret_id: "test-secret")

        with_env("SECRET_KEY_BASE_SECRET_ID" => "test-secret", "AWS_REGION" => "ap-northeast-1") do
          require "aws-sdk-secretsmanager"
          Aws::SecretsManager::Client.stub(:new, mock_client) do
            result = SecretKeyBaseProvider.fetch_from_secrets_manager

            assert_equal "sm-key", result[:current]
            assert_equal [], result[:previous]
          end
        end

        mock_client.verify
        mock_response.verify
      end

      # --- fetch delegates correctly ---

      test "fetch uses local in test environment" do
        with_env("SECRET_KEY_BASE" => "test-key", "SECRET_KEY_BASE_PREVIOUS" => nil) do
          result = SecretKeyBaseProvider.fetch

          assert_equal "test-key", result[:current]
          assert_equal [], result[:previous]
        end
      end

      test "use_secrets_manager? returns true in production when secret id is present" do
        with_env("SECRET_KEY_BASE_SECRET_ID" => "arn:aws:secretsmanager:ap-northeast-1:123:secret:test") do
          Rails.env.stub(:production?, true) do
            assert_predicate SecretKeyBaseProvider, :use_secrets_manager?
          end
        end
      end

      test "parse_local_previous wraps invalid JSON as a single previous key" do
        with_env("SECRET_KEY_BASE_PREVIOUS" => "invalid-json") do
          assert_equal ["invalid-json"], SecretKeyBaseProvider.parse_local_previous
        end
      end
    end
  end
end
