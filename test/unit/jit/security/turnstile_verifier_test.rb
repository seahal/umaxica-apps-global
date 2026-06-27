# typed: false
# frozen_string_literal: true

require "test_helper"
require "jit_security_turnstile_verifier"

module Jit
  module Security
    class TurnstileVerifierTest < ActiveSupport::TestCase
      # Pure unit test - no database/fixtures needed
      self.use_transactional_tests = false
      self.fixture_table_names = []

      def setup
        # Ensure clean state
        JitSecurityTurnstileVerifier.test_mode = false
        JitSecurityTurnstileVerifier.test_response = nil
      end

      def teardown
        JitSecurityTurnstileVerifier.test_mode = false
        JitSecurityTurnstileVerifier.test_response = nil
      end

      test "returns failure on missing token when validation active" do
        # We must disable test_mode to trigger validation logic
        JitSecurityTurnstileVerifier.test_mode = false

        result = JitSecurityTurnstileVerifier.verify(token: "", remote_ip: "127.0.0.1")

        assert_not result["success"]
        assert_equal "missing cf-turnstile-response", result["error"]
      end

      test "returns failure on missing secret when validation active" do
        JitSecurityTurnstileVerifier.test_mode = false

        # Ensure credentials/env return nil for secret key
        JitSecurityTurnstileConfig.stub(:visible_secret_key, nil) do
          result = JitSecurityTurnstileVerifier.verify(token: "token", remote_ip: "127.0.0.1")

          assert_not result["success"]
          assert_equal "missing turnstile secret", result["error"]
        end
      end

      test "returns mock response when test_response set" do
        JitSecurityTurnstileVerifier.test_response = { "success" => true, "mock" => true }
        result = JitSecurityTurnstileVerifier.verify(token: "foo", remote_ip: "127.0.0.1")

        assert result["success"]
        assert result["mock"]
      end

      test "returns success true when test_mode is true" do
        JitSecurityTurnstileVerifier.test_mode = true
        result = JitSecurityTurnstileVerifier.verify(token: "foo", remote_ip: "127.0.0.1")

        assert result["success"]
      end

      test "performs http request when verifying" do
        JitSecurityTurnstileVerifier.test_mode = false

        mock_response = Minitest::Mock.new
        mock_response.expect(:body, '{"success": true}')

        Net::HTTP.stub(:post_form, mock_response) do
          result = JitSecurityTurnstileVerifier.verify(token: "valid", remote_ip: "1.2.3.4", secret_key: "secret")

          assert result["success"]
        end

        mock_response.verify
      end

      # -- mode: :stealth -------------------------------------------------

      test "mode stealth uses JitSecurityTurnstileConfig stealth secret key" do
        JitSecurityTurnstileVerifier.test_mode = false

        mock_response = Minitest::Mock.new
        mock_response.expect(:body, '{"success": true}')

        JitSecurityTurnstileConfig.stub(:stealth_secret_key, "stealth-secret") do
          Net::HTTP.stub(:post_form, mock_response) do
            result = JitSecurityTurnstileVerifier.verify(token: "tok", remote_ip: "1.2.3.4", mode: :stealth)

            assert result["success"]
          end
        end

        mock_response.verify
      end

      test "mode stealth returns failure without HTTP when secret is nil" do
        JitSecurityTurnstileVerifier.test_mode = false

        http_called = false

        JitSecurityTurnstileConfig.stub(:stealth_secret_key, nil) do
          Net::HTTP.stub(:post_form, ->(_uri, _params) { http_called = true }) do
            result = JitSecurityTurnstileVerifier.verify(token: "tok", remote_ip: "1.2.3.4", mode: :stealth)

            assert_not result["success"]
            assert_equal "missing turnstile secret", result["error"]
          end
        end

        assert_not http_called, "HTTP should not be called when secret is nil"
      end

      test "mode visible uses JitSecurityTurnstileConfig visible secret key" do
        JitSecurityTurnstileVerifier.test_mode = false

        mock_response = Minitest::Mock.new
        mock_response.expect(:body, '{"success": true}')

        JitSecurityTurnstileConfig.stub(:visible_secret_key, "visible-secret") do
          Net::HTTP.stub(:post_form, mock_response) do
            result = JitSecurityTurnstileVerifier.verify(token: "tok", remote_ip: "1.2.3.4", mode: :visible)

            assert result["success"]
          end
        end

        mock_response.verify
      end

      test "no mode falls back to visible secret key" do
        JitSecurityTurnstileVerifier.test_mode = false

        mock_response = Minitest::Mock.new
        mock_response.expect(:body, '{"success": true}')

        JitSecurityTurnstileConfig.stub(:visible_secret_key, "visible-secret") do
          Net::HTTP.stub(:post_form, mock_response) do
            result = JitSecurityTurnstileVerifier.verify(token: "tok", remote_ip: "1.2.3.4")

            assert result["success"]
          end
        end

        mock_response.verify
      end

      test "explicit secret_key takes priority over mode" do
        JitSecurityTurnstileVerifier.test_mode = false

        mock_response = Minitest::Mock.new
        mock_response.expect(:body, '{"success": true}')

        config_called = false
        fake = -> { config_called = true; "should-not-use" }
        JitSecurityTurnstileConfig.stub(:stealth_secret_key, fake) do
          Net::HTTP.stub(:post_form, mock_response) do
            result = JitSecurityTurnstileVerifier.verify(
              token: "tok", remote_ip: "1.2.3.4", secret_key: "explicit",
              mode: :stealth,
            )

            assert result["success"]
          end
        end

        assert_not config_called, "JitSecurityTurnstileConfig should not be called when secret_key is explicit"
        mock_response.verify
      end

      test "logs sanitized response details in development" do
        JitSecurityTurnstileVerifier.test_mode = false

        mock_response = Minitest::Mock.new
        mock_response.expect(
          :body,
          {
            "success" => false,
            "error-codes" => ["timeout-or-duplicate"],
            "hostname" => "log.umaxica.app",
            "action" => "signup",
            "challenge_ts" => "2026-06-19T00:00:00Z",
            "cdata" => "opaque",
          }.to_json,
        )

        logger = Minitest::Mock.new
        logger.expect(:warn, nil) do |message|
          parsed = JSON.parse(message)

          assert_equal "turnstile.verify.response", parsed["event"]
          assert_equal "visible", parsed["data"]["mode"]
          assert_not parsed["data"]["success"]
          assert_equal "[FILTERED]", parsed["data"]["error_codes"]
          assert_equal "log.umaxica.app", parsed["data"]["hostname"]
          assert_equal "signup", parsed["data"]["action"]
          assert_equal "2026-06-19T00:00:00Z", parsed["data"]["challenge_ts"]
          assert parsed["data"]["cdata_present"]
          assert parsed["data"]["secret_key_present"]
          assert parsed["data"]["token_present"]
        end

        dev_env = ActiveSupport::StringInquirer.new("development")
        Rails.stub(:env, dev_env) do
          Rails.stub(:logger, logger) do
            JitSecurityTurnstileConfig.stub(:visible_secret_key, "visible-secret") do
              Net::HTTP.stub(:post_form, mock_response) do
                result = JitSecurityTurnstileVerifier.verify(token: "tok", remote_ip: "1.2.3.4")

                assert_not result["success"]
                assert_equal ["timeout-or-duplicate"], result["error-codes"]
              end
            end
          end
        end

        mock_response.verify
        logger.verify
      end

      test "verify_for_ceremony rejects hostname action and cdata mismatches" do
        JitSecurityTurnstileVerifier.test_mode = false

        response = {
          "success" => true,
          "hostname" => "id.app.localhost",
          "action" => "social_signup_confirmation",
          "cdata" => "ceremony-123",
          "challenge_ts" => "2026-06-19T00:00:00Z",
        }.to_json

        mock_response = Minitest::Mock.new
        mock_response.expect(:body, response)

        JitSecurityTurnstileConfig.stub(:visible_secret_key, "visible-secret") do
          Net::HTTP.stub(:post_form, mock_response) do
            failure = JitSecurityTurnstileVerifier.verify_for_ceremony(
              token: "tok",
              remote_ip: "1.2.3.4",
              ceremony_id: "ceremony-123",
              expected_action: "social_signup_confirmation",
              expected_hostname: "wrong.host",
              expected_cdata: "ceremony-123",
            )

            assert_not failure["success"]
            assert_equal "turnstile binding mismatch", failure["error"]
          end
        end

        mock_response.verify
      end

      test "verify_for_ceremony consumes replay token once and rejects replay" do
        JitSecurityTurnstileVerifier.test_mode = false

        response = {
          "success" => true,
          "hostname" => "id.app.localhost",
          "action" => "social_signup_confirmation",
          "cdata" => "ceremony-123",
          "challenge_ts" => "2026-06-19T00:00:00Z",
        }.to_json

        mock_response = Minitest::Mock.new
        mock_response.expect(:body, response)
        mock_response2 = Minitest::Mock.new
        mock_response2.expect(:body, response)

        consumed = []
        TurnstileReplayStore.stub(:consume!, ->(**kwargs) { consumed << kwargs; true }) do
          JitSecurityTurnstileConfig.stub(:visible_secret_key, "visible-secret") do
            Net::HTTP.stub(:post_form, mock_response) do
              ok = JitSecurityTurnstileVerifier.verify_for_ceremony(
                token: "tok",
                remote_ip: "1.2.3.4",
                ceremony_id: "ceremony-123",
                expected_action: "social_signup_confirmation",
                expected_hostname: "id.app.localhost",
                expected_cdata: "ceremony-123",
              )

              assert ok["success"]
            end
          end
        end

        assert_equal 1, consumed.length
        assert_equal "ceremony-123", consumed.first[:ceremony_id]

        TurnstileReplayStore.stub(:consume!, ->(**_) { raise ActiveRecord::RecordNotUnique }) do
          JitSecurityTurnstileConfig.stub(:visible_secret_key, "visible-secret") do
            Net::HTTP.stub(:post_form, mock_response2) do
              replay = JitSecurityTurnstileVerifier.verify_for_ceremony(
                token: "tok",
                remote_ip: "1.2.3.4",
                ceremony_id: "ceremony-123",
                expected_action: "social_signup_confirmation",
                expected_hostname: "id.app.localhost",
                expected_cdata: "ceremony-123",
              )

              assert_not replay["success"]
              assert_equal "turnstile replay detected", replay["error"]
            end
          end
        end

        mock_response.verify
        mock_response2.verify
      end

      test "does not log response details outside development" do
        JitSecurityTurnstileVerifier.test_mode = false

        mock_response = Minitest::Mock.new
        mock_response.expect(:body, '{"success": true}')

        logger = Minitest::Mock.new

        Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
          Rails.stub(:logger, logger) do
            Net::HTTP.stub(:post_form, mock_response) do
              result = JitSecurityTurnstileVerifier.verify(
                token: "tok",
                remote_ip: "1.2.3.4",
                secret_key: "explicit",
              )

              assert result["success"]
            end
          end
        end

        mock_response.verify
        logger.verify
      end
    end
  end
end
