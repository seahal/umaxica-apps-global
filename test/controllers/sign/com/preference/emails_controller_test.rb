# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Com
    module Preference
      class EmailsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @host = ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")
          @visitor = create_verified_visitor_with_email(
            email_address: "visitor-unsubscribe-#{SecureRandom.hex(4)}@example.com",
          )
          @email = @visitor.visitor_emails.first
          @token = @email.promotional_unsubscribe_token
          host! @host
        end

        test "GET edit renders unsubscribe confirmation for a valid token" do
          get edit_sign_com_preference_email_path(@email, ri: "jp", token: @token)

          assert_response :success
          assert_match "Unsubscribe", response.body
        end

        test "DELETE destroy turns visitor promotional email off after confirmation" do
          get edit_sign_com_preference_email_path(@email, ri: "jp", token: @token)

          assert_response :success

          delete sign_com_preference_email_path(@email), params: { token: @token }

          assert_redirected_to edit_sign_com_preference_email_path(@email, token: @token)
          assert_not @email.reload.promotional
        end

        test "POST create turns visitor promotional email off" do
          post sign_com_preference_email_path(@email), params: { token: @token }

          assert_response :ok
          assert_not @email.reload.promotional
        end

        test "missing token does not unsubscribe visitor email" do
          post sign_com_preference_email_path(@email)

          assert_response :not_found
          assert @email.reload.promotional
        end
      end
    end
  end
end
