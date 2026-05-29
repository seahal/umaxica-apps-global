# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module App
    module Preference
      class EmailsControllerTest < ActionDispatch::IntegrationTest
        fixtures_none!

        setup do
          @host = ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
          email_address = "client-unsubscribe-#{SecureRandom.hex(4)}@example.com"
          @user = create_verified_user_with_email(email_address: email_address)
          @email = @user.client_emails.first
          @token = @email.promotional_unsubscribe_token
          host! @host
          CloudflareTurnstile.test_mode = true
          CloudflareTurnstile.test_validation_response = { "success" => true }
        end

        teardown do
          CloudflareTurnstile.test_mode = false
          CloudflareTurnstile.test_validation_response = nil
        end

        test "controller uses bare unsubscribe boundary" do
          assert_operator Sign::App::Preference::EmailsController, :<, Sign::App::BareController
          assert_not_operator Sign::App::Preference::EmailsController, :<, Sign::App::PreferencesBaseController
        end

        test "GET edit renders unsubscribe confirmation for a valid token" do
          get edit_sign_app_preference_email_path(@email, ri: "jp", token: @token)

          assert_response :success
          assert_match "Unsubscribe", response.body
          assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
          assert_includes response.body, 'data-turnstile-mode-value="render"'
        end

        test "DELETE destroy turns promotional email off" do
          delete sign_app_preference_email_path(@email), params: { token: @token, "cf-turnstile-response": "test" }

          assert_redirected_to edit_sign_app_preference_email_path(@email, token: @token)
          assert_not @email.reload.promotional
        end

        test "DELETE destroy keeps promotional email on when turnstile fails" do
          CloudflareTurnstile.test_mode = true
          CloudflareTurnstile.test_validation_response = { "success" => false }

          delete(sign_app_preference_email_path(@email), params: { token: @token, "cf-turnstile-response": "test" })

          assert_redirected_to edit_sign_app_preference_email_path(@email, token: @token)
          assert_equal I18n.t("turnstile_error"), flash[:alert]
          assert @email.reload.promotional
        ensure
          CloudflareTurnstile.test_validation_response = { "success" => true }
        end

        test "POST create supports one-click unsubscribe without csrf token" do
          post sign_app_preference_email_path(@email), params: { token: @token }

          assert_response :ok
          assert_not @email.reload.promotional
        end

        test "POST create supports one-click unsubscribe when forgery protection is enabled" do
          with_forgery_protection do
            post(sign_app_preference_email_path(@email), params: { token: @token })

            assert_response :ok
            assert_not @email.reload.promotional
          end
        end

        test "DELETE destroy without csrf token is rejected when forgery protection is enabled" do
          with_forgery_protection do
            delete sign_app_preference_email_path(@email), params: { token: @token, "cf-turnstile-response": "test" }

            assert_response :unprocessable_content
            assert @email.reload.promotional
          end
        end

        test "invalid token does not unsubscribe" do
          delete sign_app_preference_email_path(@email), params: { token: "invalid" }

          assert_response :not_found
          assert @email.reload.promotional
        end
      end
    end
  end
end
