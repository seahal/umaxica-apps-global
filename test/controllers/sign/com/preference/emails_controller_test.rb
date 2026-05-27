# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Com
    module Preference
      class EmailsControllerTest < ActionDispatch::IntegrationTest
        fixtures_only :visitor_statuses,
                      :visitor_visibilities,
                      :visitor_multi_factors,
                      :visitor_multi_factor_statuses,
                      :visitor_email_statuses,
                      :visitor_telephone_statuses

        setup do
          @host = ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")
          @visitor = create_verified_visitor_with_email(
            email_address: "visitor-unsubscribe-#{SecureRandom.hex(4)}@example.com",
          )
          @email = @visitor.visitor_emails.first
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
          assert_operator Sign::Com::Preference::EmailsController, :<, Sign::Com::BareController
          assert_not_operator Sign::Com::Preference::EmailsController, :<, Sign::Com::PreferencesBaseController
        end

        test "GET edit renders unsubscribe confirmation for a valid token" do
          get edit_sign_com_preference_email_path(@email, ri: "jp", token: @token)

          assert_response :success
          assert_match "Unsubscribe", response.body
          assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
          assert_includes response.body, "turnstile.render"
        end

        test "DELETE destroy turns visitor promotional email off after confirmation" do
          get edit_sign_com_preference_email_path(@email, ri: "jp", token: @token)

          assert_response :success

          delete sign_com_preference_email_path(@email), params: { token: @token, "cf-turnstile-response": "test" }

          assert_redirected_to edit_sign_com_preference_email_path(@email, token: @token)
          assert_not @email.reload.promotional
        end

        test "DELETE destroy keeps visitor promotional email on when turnstile fails" do
          CloudflareTurnstile.test_mode = true
          CloudflareTurnstile.test_validation_response = { "success" => false }

          delete(sign_com_preference_email_path(@email), params: { token: @token, "cf-turnstile-response": "test" })

          assert_redirected_to edit_sign_com_preference_email_path(@email, token: @token)
          assert_equal I18n.t("turnstile_error"), flash[:alert]
          assert @email.reload.promotional
        ensure
          CloudflareTurnstile.test_validation_response = { "success" => true }
        end

        test "POST create turns visitor promotional email off" do
          post sign_com_preference_email_path(@email), params: { token: @token }

          assert_response :ok
          assert_not @email.reload.promotional
        end

        test "POST create supports one-click unsubscribe when forgery protection is enabled" do
          with_forgery_protection do
            post sign_com_preference_email_path(@email), params: { token: @token }

            assert_response :ok
            assert_not @email.reload.promotional
          end
        end

        test "DELETE destroy without csrf token is rejected when forgery protection is enabled" do
          with_forgery_protection do
            delete sign_com_preference_email_path(@email), params: { token: @token, "cf-turnstile-response": "test" }

            assert_response :unprocessable_content
            assert @email.reload.promotional
          end
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
