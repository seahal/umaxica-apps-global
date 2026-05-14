# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

module Sign::App::Up
  class TelephonesControllerTest < ActionDispatch::IntegrationTest
    fixtures :app_preference_chronicle_levels, :app_preference_chronicle_events,
             :user_statuses, :user_telephone_statuses,
             :user_chronicle_events, :user_chronicle_levels
    include ActiveJob::TestHelper
    include ActiveSupport::Testing::TimeHelpers

    setup do
      host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      cookies["csrf_token"] = csrf_token_value
      # Mock Cloudflare Turnstile validation
      CloudflareTurnstile.test_mode = true
      CloudflareTurnstile.test_validation_response = { "success" => true }
    end

    teardown do
      CloudflareTurnstile.test_mode = false
      CloudflareTurnstile.test_validation_response = nil
    end

    test "should get new" do
      get new_sign_app_up_telephone_url(ri: "jp")

      assert_response :success
    end

    test "new redirects to dashboard when user is already logged in" do
      user = User.create!(status_id: UserStatus::VERIFIED_WITH_SIGN_UP)

      get new_sign_app_up_telephone_url(ri: "jp"),
          headers: as_user_headers(user, host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))

      assert_redirected_to sign_app_dashboard_url(ri: "jp")
    end

    test "create rejects when user is already logged in" do
      user = User.create!(status_id: UserStatus::VERIFIED_WITH_SIGN_UP)

      assert_no_difference("UserTelephone.count") do
        post sign_app_up_telephones_url(ri: "jp"),
             params: {
               user_telephone: {
                 raw_number: "+1234567890",
                 confirm_policy: "1",
                 confirm_using_mfa: "1",
               },
               "cf-turnstile-response": "test",
             },
             headers: as_user_headers(user, host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))
      end

      assert_response :unauthorized
      assert_equal I18n.t("errors.messages.not_authorized"), response.body
    end

    test "edit route uses id path parameter" do
      post sign_app_up_telephones_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone

      get edit_sign_app_up_telephone_url(telephone, ri: "jp")

      assert_response :success
      assert_equal telephone.public_id, request.path_parameters[:id]
      assert_nil request.path_parameters[:public_id]
    end

    test "should create telephone and redirect to edit" do
      assert_enqueued_jobs 1, only: SmsDeliveryJob do
        assert_difference("UserTelephone.count") do
          post sign_app_up_telephones_url(ri: "jp"), params: {
            user_telephone: {
              raw_number: "+1234567890",
              confirm_policy: "1",
              confirm_using_mfa: "1",
            },
            "cf-turnstile-response": "test",
          }
        end
      end

      telephone = registration_telephone

      assert_redirected_to edit_sign_app_up_telephone_url(telephone, regional_defaults)
      assert_not_nil session[:user_telephone_registration]
    end

    test "create with existing telephone still redirects and does not create a new record" do
      user = User.create!(status_id: UserStatus::VERIFIED_WITH_SIGN_UP)
      existing_telephone = UserTelephone.create!(
        user: user,
        number: "+1234567898",
        user_telephone_status_id: UserTelephoneStatus::VERIFIED,
        confirm_policy: "1",
        confirm_using_mfa: "1",
      )

      assert_enqueued_jobs 1, only: SmsDeliveryJob do
        assert_no_difference("User.count") do
          assert_no_difference("UserTelephone.count") do
            post sign_app_up_telephones_url(ri: "jp"), params: {
              user_telephone: {
                raw_number: existing_telephone.number,
                confirm_policy: "1",
                confirm_using_mfa: "1",
              },
              "cf-turnstile-response": "test",
            }
          end
        end
      end

      assert_redirected_to edit_sign_app_up_telephone_url(existing_telephone, regional_defaults)
      assert_equal I18n.t("sign.app.registration.telephone.create.verification_code_sent"), flash[:notice]
      assert_nil flash[:alert]
    end

    test "create shows identical user-facing response for existing and new telephones" do
      user = User.create!(status_id: UserStatus::VERIFIED_WITH_SIGN_UP)
      existing_telephone = UserTelephone.create!(
        user: user,
        number: "+819012345678",
        user_telephone_status_id: UserTelephoneStatus::VERIFIED,
        confirm_policy: "1",
        confirm_using_mfa: "1",
      )

      post sign_app_up_telephones_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: existing_telephone.number,
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      existing_location = response.location
      existing_notice = flash[:notice]

      post sign_app_up_telephones_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+819012300000",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      assert_response :redirect
      assert_match(%r{/up/telephones/[^/]+/edit}, response.location)
      assert_equal existing_notice, flash[:notice]
      assert_match(%r{/up/telephones/[^/]+/edit}, existing_location)
    end

    test "rejects invalid telephone format" do
      post sign_app_up_telephones_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "invalid-telephone",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      assert_response :unprocessable_content
    end

    test "create renders unprocessable when user_telephone param missing" do
      assert_enqueued_jobs 0, only: SmsDeliveryJob do
        assert_no_difference("User.count") do
          assert_no_difference("UserTelephone.count") do
            post sign_app_up_telephones_url(ri: "jp"), params: {
              "cf-turnstile-response": "test",
            }
          end
        end
      end

      assert_response :unprocessable_content
    end

    test "create with turnstile failure returns unprocessable content" do
      CloudflareTurnstile.test_validation_response = { "success" => false }

      assert_enqueued_jobs 0, only: SmsDeliveryJob do
        assert_no_difference("User.count") do
          assert_no_difference("UserTelephone.count") do
            post sign_app_up_telephones_url(ri: "jp"), params: {
              user_telephone: {
                raw_number: "+1234567897",
                confirm_policy: "1",
                confirm_using_mfa: "1",
              },
              "cf-turnstile-response": "test",
            }
          end
        end
      end

      assert_response :unprocessable_content
    end

    test "should update telephone with valid otp" do
      # 1. Create telephone via request to set up session
      post sign_app_up_telephones_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone

      # 2. Retrieve OTP from DB
      otp_data = telephone.get_otp
      hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
      code = hotp.at(otp_data[:otp_counter])

      # 3. Submit OTP
      patch sign_app_up_telephone_url(telephone, ri: "jp"), params: {
        user_telephone: { pass_code: code },
      }

      assert_redirected_to sign_app_up_telephone_passkey_registration_url(telephone, regional_defaults)

      telephone.reload

      # OTP should be cleared (-infinity)
      expires = telephone.otp_expires_at

      assert expires.nil? || expires.to_s == "-infinity" || (expires.is_a?(Float) && expires == -Float::INFINITY)
      assert_equal [nil, nil], [telephone.confirm_policy, telephone.confirm_using_mfa]
    end

    test "should log in after sms verification when passkey already exists" do
      post sign_app_up_telephones_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+1234567891",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone
      user = telephone.user

      UserEmail.create!(
        user: user,
        address: "test_verified_#{user.id}@example.com",
        user_email_status_id: UserEmailStatus::VERIFIED,
        otp_private_key: ROTP::Base32.random,
      )

      UserPasskey.create!(
        user: user,
        webauthn_id: Base64.urlsafe_encode64("preexisting_passkey", padding: false),
        public_key: "public_key",
        sign_count: 0,
        description: "Existing Passkey",
        status_id: UserPasskeyStatus::ACTIVE,
      )

      otp_data = telephone.get_otp
      hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
      code = hotp.at(otp_data[:otp_counter])

      assert_difference("UserToken.count", 1) do
        patch sign_app_up_telephone_url(telephone, ri: "jp"), params: {
          user_telephone: { pass_code: code },
        }
      end

      assert_redirected_to sign_app_dashboard_url(ri: "jp")
      assert_predicate cookies[Authentication::Base::ACCESS_COOKIE_KEY], :present?
    end

    test "should create audit record on sms login with existing passkey" do
      post sign_app_up_telephones_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+1234567892",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone
      user = telephone.user

      UserEmail.create!(
        user: user,
        address: "audit_test_verified_#{user.id}@example.com",
        user_email_status_id: UserEmailStatus::VERIFIED,
        otp_private_key: ROTP::Base32.random,
      )

      UserPasskey.create!(
        user: user,
        webauthn_id: Base64.urlsafe_encode64("audit_test_passkey", padding: false),
        public_key: "public_key",
        sign_count: 0,
        description: "Audit Test Passkey",
        status_id: UserPasskeyStatus::ACTIVE,
      )

      otp_data = telephone.get_otp
      hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
      code = hotp.at(otp_data[:otp_counter])

      patch sign_app_up_telephone_url(telephone, ri: "jp"), params: {
        user_telephone: { pass_code: code },
      }

      signup_audit = UserChronicle.where(
        event_id: UserChronicleEvent::SIGNED_UP_WITH_TELEPHONE,
        actor_id: user.id,
      ).last

      assert_not_nil signup_audit
      assert_equal "User", signup_audit.actor_type

      login_audit = UserChronicle.where(
        event_id: UserChronicleEvent::LOGGED_IN,
        actor_id: user.id,
      ).last

      assert_not_nil login_audit
      assert_equal "telephone", login_audit.context["auth_method"]
    end

    test "should reject blank pass code" do
      post sign_app_up_telephones_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone

      patch sign_app_up_telephone_url(telephone, ri: "jp"), params: {
        user_telephone: { pass_code: "" },
      }

      assert_response :unprocessable_content
    end

    test "should lockout after max failed otp attempts" do
      post sign_app_up_telephones_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+1234567893",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone
      user = telephone.user

      Prosopite.pause do
        Telephone::MAX_OTP_ATTEMPTS.times do
          patch sign_app_up_telephone_url(telephone, ri: "jp"), params: {
            user_telephone: { pass_code: "000000" },
          }
        end
      end

      assert_redirected_to new_sign_app_up_telephone_url(ri: "jp")
      assert_equal I18n.t("sign.app.registration.telephone.update.attempts_exceeded"), flash[:alert]

      assert UserTelephone.exists?(telephone.id)
      assert User.exists?(user.id)
      assert_predicate telephone.reload, :locked?
      assert_nil session[:user_telephone_registration]
    end

    test "should cleanup existing unverified telephones on create" do
      # Create first registration
      post sign_app_up_telephones_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+1234567894",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      first_telephone = registration_telephone
      first_user = first_telephone.user

      travel Common::OtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second do
        # Create second registration with the same number
        post sign_app_up_telephones_url(ri: "jp"), params: {
          user_telephone: {
            raw_number: "+1234567894",
            confirm_policy: "1",
            confirm_using_mfa: "1",
          },
          "cf-turnstile-response": "test",
        }
      end

      # First telephone and its pending user should be cleaned up
      assert_not UserTelephone.exists?(first_telephone.id)
      assert_not User.exists?(first_user.id)
    end

    test "create rejects duplicate unverified telephone inside overwrite window" do
      post sign_app_up_telephones_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+1234567895",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      first_telephone = registration_telephone
      first_user = first_telephone.user

      assert_no_difference("UserTelephone.count") do
        assert_no_difference("User.count") do
          post sign_app_up_telephones_url(ri: "jp"), params: {
            user_telephone: {
              raw_number: "+1234567895",
              confirm_policy: "1",
              confirm_using_mfa: "1",
            },
            "cf-turnstile-response": "test",
          }
        end
      end

      assert_response :too_many_requests
      assert UserTelephone.exists?(first_telephone.id)
      assert User.exists?(first_user.id)
    end

    test "resend sends code for active registration session" do
      post sign_app_up_telephones_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone

      assert_enqueued_jobs 1, only: SmsDeliveryJob do
        post resend_sign_app_up_telephones_url(ri: "jp")
      end

      assert_redirected_to edit_sign_app_up_telephone_url(telephone, ri: "jp")
      assert_predicate session[:user_telephone_otp_last_sent_at], :present?
    end

    test "resend returns success even without registration session" do
      assert_no_difference("UserTelephone.count") do
        assert_enqueued_jobs 0, only: SmsDeliveryJob do
          post resend_sign_app_up_telephones_url(ri: "jp")
        end
      end

      assert_redirected_to new_sign_app_up_telephone_url(ri: "jp")
    end

    test "resend rate limits repeated requests" do
      post sign_app_up_telephones_url(ri: "jp"), params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone

      assert_enqueued_jobs 1, only: SmsDeliveryJob do
        post resend_sign_app_up_telephones_url(ri: "jp")
      end
      assert_enqueued_jobs 0, only: SmsDeliveryJob do
        post resend_sign_app_up_telephones_url(ri: "jp")
      end

      assert_redirected_to edit_sign_app_up_telephone_url(telephone, ri: "jp")
      assert_equal I18n.t("sign.app.registration.telephone.resend.rate_limited"), flash[:alert]
    end

    test "resend cooldown is 30 seconds" do
      assert_enqueued_jobs 0, only: SmsDeliveryJob do
        post resend_sign_app_up_telephones_url(ri: "jp")
      end
      sent_at = session[:user_telephone_otp_last_sent_at]

      assert_predicate sent_at, :present?
      assert_redirected_to new_sign_app_up_telephone_url(ri: "jp")
      assert_equal I18n.t("sign.app.registration.telephone.resend.sent"), flash[:notice]

      travel 29.seconds do
        assert_enqueued_jobs 0, only: SmsDeliveryJob do
          post resend_sign_app_up_telephones_url(ri: "jp")
        end
        assert_redirected_to new_sign_app_up_telephone_url(ri: "jp")
        assert_equal I18n.t("sign.app.registration.telephone.resend.rate_limited"), flash[:alert]
      end

      travel 31.seconds do
        assert_enqueued_jobs 0, only: SmsDeliveryJob do
          post resend_sign_app_up_telephones_url(ri: "jp")
        end
        assert_redirected_to new_sign_app_up_telephone_url(ri: "jp")
        assert_equal I18n.t("sign.app.registration.telephone.resend.sent"), flash[:notice]
      end
    end

    private

    def regional_defaults
      { ri: "jp" }
    end

    def registration_telephone
      registration_session = session[:user_telephone_registration] || {}
      public_id = registration_session[:public_id] || registration_session["public_id"]
      UserTelephone.find_by!(public_id: public_id)
    end

    def post(path, **options)
      options[:headers] = browser_headers.merge(options[:headers] || {})
      super
    end

    def patch(path, **options)
      options[:headers] = browser_headers.merge(options[:headers] || {})
      super
    end
  end
end
