# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module App
    module Preference
      class EmailsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @host = ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
          @user = create_verified_user_with_email(email_address: "client-unsubscribe-#{SecureRandom.hex(4)}@example.com")
          @email = @user.user_emails.first
          @token = @email.promotional_unsubscribe_token
          host! @host
        end

        test "GET edit renders unsubscribe confirmation for a valid token" do
          get edit_sign_app_preference_email_path(@email, ri: "jp", token: @token)

          assert_response :success
          assert_match "Unsubscribe", response.body
        end

        test "DELETE destroy turns promotional email off" do
          delete sign_app_preference_email_path(@email), params: { token: @token }

          assert_redirected_to edit_sign_app_preference_email_path(@email, token: @token)
          assert_not @email.reload.promotional
        end

        test "POST create supports one-click unsubscribe without csrf token" do
          post sign_app_preference_email_path(@email), params: { token: @token }

          assert_response :ok
          assert_not @email.reload.promotional
        end

        test "POST create supports one-click unsubscribe when forgery protection is enabled" do
          previous = ActionController::Base.allow_forgery_protection
          ActionController::Base.allow_forgery_protection = true

          post(sign_app_preference_email_path(@email), params: { token: @token })

          assert_response :ok
          assert_not @email.reload.promotional
        ensure
          ActionController::Base.allow_forgery_protection = previous
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
