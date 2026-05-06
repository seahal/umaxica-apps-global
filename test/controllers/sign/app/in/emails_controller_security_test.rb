# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module App
    module In
      class EmailsControllerSecurityTest < ActionDispatch::IntegrationTest
        fixtures :users, :user_statuses, :user_email_statuses

        setup do
          host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
          CloudflareTurnstile.test_mode = true
        end

        teardown do
          CloudflareTurnstile.test_mode = false
          CloudflareTurnstile.test_validation_response = nil
        end

        test "rejects invalid email format" do
          post sign_app_in_email_url(ri: "jp"), params: {
            user_email: { address: "invalid-email" },
          }

          assert_response :unprocessable_content
        end

        test "accepts valid emails with consecutive special characters" do
          # Test that user+tag@example.co.uk format is accepted
          # (This will redirect because email doesn't exist, preventing enumeration)
          post sign_app_in_email_url(ri: "jp"), params: {
            :user_email => { address: "user+tag@example.co.uk" },
            "cf-turnstile-response" => "test_token",
          }

          # Should proceed past format validation
          assert_response :found
        end

        test "accepts valid emails with dots in local part" do
          post sign_app_in_email_url(ri: "jp"), params: {
            :user_email => { address: "user.name@example.com" },
            "cf-turnstile-response" => "test_token",
          }

          # Should proceed past format validation
          assert_response :found
        end

        test "accepts valid emails with underscores" do
          post sign_app_in_email_url(ri: "jp"), params: {
            :user_email => { address: "user_name@example.co.uk" },
            "cf-turnstile-response" => "test_token",
          }

          # Should proceed past format validation
          assert_response :found
        end

        test "accepts Gmail-style addressing with plus" do
          post sign_app_in_email_url(ri: "jp"), params: {
            :user_email => { address: "user+mailbox@gmail.com" },
            "cf-turnstile-response" => "test_token",
          }

          # Should proceed past format validation
          assert_response :found
        end

        test "accepts emails with multiple domain levels" do
          post sign_app_in_email_url(ri: "jp"), params: {
            :user_email => { address: "user@mail.example.co.uk" },
            "cf-turnstile-response" => "test_token",
          }

          # Should proceed past format validation
          assert_response :found
        end

        test "rejects emails without @ symbol" do
          post sign_app_in_email_url(ri: "jp"), params: {
            user_email: { address: "usernameexample.com" },
          }

          assert_response :unprocessable_content
        end

        test "rejects emails without domain" do
          post sign_app_in_email_url(ri: "jp"), params: {
            user_email: { address: "user@" },
          }

          assert_response :unprocessable_content
        end

        test "rejects emails without local part" do
          post sign_app_in_email_url(ri: "jp"), params: {
            user_email: { address: "@example.com" },
          }

          assert_response :unprocessable_content
        end

        test "rejects emails with spaces" do
          post sign_app_in_email_url(ri: "jp"), params: {
            user_email: { address: "user name@example.com" },
          }

          assert_response :unprocessable_content
        end

        test "normalizes email to lowercase" do
          post sign_app_in_email_url(ri: "jp"), params: {
            :user_email => { address: "TEST@EXAMPLE.COM" },
            "cf-turnstile-response" => "test_token",
          }

          # Email should be normalized to lowercase in validation and proceed
          assert_response :found
        end

        test "rejects emails with excessive whitespace" do
          post sign_app_in_email_url(ri: "jp"), params: {
            :user_email => { address: "  test@example.com  " },
            "cf-turnstile-response" => "test_token",
          }

          # Whitespace should be stripped and validated, then proceed
          assert_response :found
        end

        test "handles OTP in database" do
          user = users(:one)
          # Create existing email
          UserEmail.create!(user: user, address: "otp_test@example.com", confirm_policy: true)

          # Request OTP
          post sign_app_in_email_url(ri: "jp"), params: {
            :user_email => { address: "otp_test@example.com" },
            "cf-turnstile-response" => "test_token",
          }

          email = UserEmail.find_by(address: "otp_test@example.com")

          assert_not_nil email.reload.otp_private_key
          assert_not_nil email.otp_counter
        end

        test "cleans up OTP secrets after verification" do
          user = users(:one)
          # Create existing email
          email = UserEmail.create!(user: user, address: "cleanup_test@example.com", confirm_policy: true)

          # Request OTP to generate secrets
          post sign_app_in_email_url(ri: "jp"), params: {
            :user_email => { address: "cleanup_test@example.com" },
            "cf-turnstile-response" => "test_token",
          }

          email.reload
          otp_code = ROTP::HOTP.new(email.otp_private_key).at(Integer(email.otp_counter.to_s, 10))

          patch sign_app_in_email_url(ri: "jp"), params: {
            user_email: { pass_code: otp_code },
          }

          assert_response :found # Redirects on success

          email.reload

          assert_equal "0", email.otp_counter
          assert_equal 0, email.otp_attempts_count
        end
      end
    end
  end
end
