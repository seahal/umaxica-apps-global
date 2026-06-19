# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

module Sign::App::Up
  class TelephonesControllerTest < ActionDispatch::IntegrationTest
    fixtures :app_preference_chronicle_levels, :app_preference_chronicle_events,
             :client_statuses, :client_telephone_statuses,
             :client_chronicle_events, :client_chronicle_levels
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
      get new_sign_app_sign_up_telephone_url(ri: "jp")

      assert_response :success
    end

    test "new redirects to dashboard when user is already logged in" do
      user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)

      get new_sign_app_sign_up_telephone_url(ri: "jp"),
          headers: as_user_headers(user, host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))

      assert_response :unauthorized
      assert_equal "すでにログインしています", response.body
    end

    test "create rejects when user is already logged in" do
      user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)

      assert_no_difference("ClientTelephone.count") do
        post sign_app_sign_up_telephone_url(ri: "jp"),
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
      assert_equal "すでにログインしています", response.body
    end

    test "edit route uses registration session" do
      post sign_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone

      get sign_app_sign_up_check_telephone_otp_url(ri: "jp")

      assert_response :success
      assert_nil request.path_parameters[:id]
      assert_equal telephone.public_id, session.dig(:user_telephone_registration, "public_id")
      assert_select "h1", text: I18n.t("sign.app.registration.telephone.edit.page_title")
      assert_select "label", text: I18n.t("sign.app.registration.telephone.edit.code_label")
      assert_select "input[placeholder=?]", I18n.t("sign.app.registration.telephone.edit.code_placeholder")
      assert_select "input[type=submit][value=?]", I18n.t("sign.app.registration.telephone.edit.submit")
      assert_includes response.body, "電話番号"
      assert_includes response.body, "SMS"
      assert_includes response.body, I18n.t("sign.app.registration.telephone.edit.delivery_help")
      assert_not_includes response.body, "prohibited this sample from being saved"
    end

    test "should create telephone and redirect to edit" do
      assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
        assert_difference("ClientTelephone.count") do
          post sign_app_sign_up_telephone_url, params: {
            client_telephone: {
              raw_number: "+1234567890",
              confirm_policy: "1",
              confirm_using_mfa: "1",
            },
            "cf-turnstile-response": "test",
          }
        end
      end

      registration_telephone

      assert_redirected_to sign_app_sign_up_check_telephone_otp_url
      assert_not_nil session[:user_telephone_registration]
      assert_predicate session[:app_sign_up_flow_locator], :present?
      cycle = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))

      assert_equal ClientSignUpFlowStatus::CONTACT_PENDING, cycle.status_id
      assert_equal "telephone", cycle.entry_method
      assert_equal registration_telephone.id, cycle.pending_contact_id
    end

    test "new page does not use sample wording in error summary" do
      get new_sign_app_sign_up_telephone_url(ri: "jp")

      assert_response :success
      assert_not_includes response.body, "prohibited this sample from being saved"
      assert_includes response.body, "prohibited this telephone from being saved"
    end

    test "create with existing telephone still redirects and does not create a new record" do
      user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
      existing_telephone = ClientTelephone.create!(
        user: user,
        number: "+1234567898",
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
        confirm_policy: "1",
        confirm_using_mfa: "1",
      )

      assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
        assert_no_difference("Client.count") do
          assert_no_difference("ClientTelephone.count") do
            post sign_app_sign_up_telephone_url, params: {
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

      assert_redirected_to sign_app_sign_up_check_telephone_otp_url
      assert_equal I18n.t("sign.app.registration.telephone.create.verification_code_sent"), flash[:notice]
      assert_nil flash[:alert]
    end

    test "create shows identical user-facing response for existing and new telephones" do
      user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
      existing_telephone = ClientTelephone.create!(
        user: user,
        number: "+819012345678",
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
        confirm_policy: "1",
        confirm_using_mfa: "1",
      )

      post sign_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: existing_telephone.number,
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      existing_location = response.location
      existing_notice = flash[:notice]

      post sign_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+819012300000",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      assert_response :redirect
      assert_match(%r{/up/check/telephone/otp}, response.location)
      assert_equal existing_notice, flash[:notice]
      assert_match(%r{/up/check/telephone/otp}, existing_location)
    end

    test "rejects invalid telephone format" do
      logged =
        capture_telephone_log do
          post(
            sign_app_sign_up_telephone_url, params: {
              user_telephone: {
                raw_number: "invalid-telephone",
                confirm_policy: "1",
                confirm_using_mfa: "1",
              },
              "cf-turnstile-response": "test",
            },
          )
        end

      assert_includes logged, "sign.signup.telephone.create.received"
      assert_includes logged, "sign.signup.telephone.create.rejected"
      assert_includes logged, "telephone_invalid"

      assert_response :unprocessable_content
    end

    test "create renders unprocessable when user_telephone param missing" do
      assert_enqueued_jobs 0, only: Outbound::SmsDeliveryJob do
        assert_no_difference("Client.count") do
          assert_no_difference("ClientTelephone.count") do
            post sign_app_sign_up_telephone_url, params: {
              "cf-turnstile-response": "test",
            }
          end
        end
      end

      assert_response :unprocessable_content
    end

    test "create with turnstile failure returns unprocessable content" do
      CloudflareTurnstile.test_validation_response = { "success" => false }

      assert_enqueued_jobs 0, only: Outbound::SmsDeliveryJob do
        assert_no_difference("Client.count") do
          assert_no_difference("ClientTelephone.count") do
            post sign_app_sign_up_telephone_url, params: {
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

    def capture_telephone_log
      io = StringIO.new
      original = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(io)
      yield
      io.string
    ensure
      Rails.logger = original
    end

    test "should update telephone with valid otp" do
      # 1. Create telephone via request to set up session
      post sign_app_sign_up_telephone_url, params: {
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
      patch sign_app_sign_up_check_telephone_otp_url(ri: "jp"), params: {
        user_telephone: { pass_code: code },
      }

      assert_redirected_to sign_app_sign_up_guard_telephone_url(regional_defaults)

      telephone.reload
      cycle = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))

      # OTP should be cleared (-infinity)
      expires = telephone.otp_expires_at

      assert expires.nil? || expires.to_s == "-infinity" || (expires.is_a?(Float) && expires == -Float::INFINITY)
      assert_equal [nil, nil], [telephone.confirm_policy, telephone.confirm_using_mfa]
      assert_equal ClientSignUpFlowStatus::CHECKPOINT_PENDING, cycle.status_id
      assert_equal "checkpoint", cycle.step
    end

    test "otp success keeps telephone pending and records cycle proof in session" do
      post sign_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone

      otp_data = telephone.get_otp
      hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
      code = hotp.at(otp_data[:otp_counter])

      assert_no_difference("ClientToken.count") do
        patch sign_app_sign_up_check_telephone_otp_url(ri: "jp"), params: {
          user_telephone: { pass_code: code },
        }
      end

      assert_redirected_to sign_app_sign_up_guard_telephone_url(regional_defaults)

      # The telephone must stay UNVERIFIED_WITH_SIGN_UP so an abandoned cycle
      # stays collectable by the pending-signup cleanup (no number lock).
      assert_equal ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
                   telephone.reload.user_telephone_status_id
      assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY].presence

      registration = session[:user_telephone_registration]
      otp_verified = registration[:otp_verified] || registration["otp_verified"]

      assert otp_verified
    end

    test "telephone sign up still requires passkey even if pending user has a passkey" do
      post sign_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567891",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone
      user = telephone.user

      ClientPasskey.create!(
        user: user,
        webauthn_id: Base64.urlsafe_encode64("preexisting_passkey", padding: false),
        public_key: "public_key",
        sign_count: 0,
        description: "Existing Passkey",
        status_id: ClientPasskeyStatus::ACTIVE,
      )

      otp_data = telephone.get_otp
      hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
      code = hotp.at(otp_data[:otp_counter])

      # A pre-existing passkey row must not let OTP success short-circuit into
      # a signed-in session: telephone sign-up always routes through the
      # passkey step and the durable finalizer.
      assert_no_difference("ClientToken.count") do
        patch sign_app_sign_up_check_telephone_otp_url(ri: "jp"), params: {
          user_telephone: { pass_code: code },
        }
      end

      assert_redirected_to sign_app_sign_up_guard_telephone_url(regional_defaults)
      assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY].presence
      assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, user.reload.status_id

      get sign_app_sign_up_guard_telephone_url(regional_defaults)

      assert_redirected_to sign_app_sign_up_check_telephone_passkey_url(regional_defaults)

      get sign_app_sign_up_check_telephone_passkey_url(regional_defaults)

      assert_response :success
      assert_select "[data-controller='passkey-registration']"
    end

    test "abandoned telephone sign up after otp can re-register the same number" do
      number = "+1234567892"

      post sign_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: number,
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone
      abandoned_user_id = telephone.user_id

      otp_data = telephone.get_otp
      hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
      code = hotp.at(otp_data[:otp_counter])

      patch sign_app_sign_up_check_telephone_otp_url(ri: "jp"), params: {
        user_telephone: { pass_code: code },
      }
      # Cycle abandoned here: OTP passed but passkey never completed.

      # Past the re-registration overwrite window the same number must be
      # registrable again -- the abandoned pending row/user is cleaned up.
      travel(CommonOtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second) do
        post sign_app_sign_up_telephone_url, params: {
          user_telephone: {
            raw_number: number,
            confirm_policy: "1",
            confirm_using_mfa: "1",
          },
          "cf-turnstile-response": "test",
        }
      end

      assert_redirected_to sign_app_sign_up_check_telephone_otp_url
      new_telephone = registration_telephone

      assert_not_equal telephone.id, new_telephone.id
      assert_not ClientTelephone.exists?(telephone.id)
      assert_not Client.exists?(abandoned_user_id)
      assert_equal ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
                   new_telephone.user_telephone_status_id
    end

    test "should reject blank pass code" do
      post sign_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      registration_telephone

      patch sign_app_sign_up_check_telephone_otp_url(ri: "jp"), params: {
        user_telephone: { pass_code: "" },
      }

      assert_response :unprocessable_content
    end

    test "should lockout after max failed otp attempts" do
      post sign_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567893",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      telephone = registration_telephone
      user = telephone.user
      cycle = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
      completed_requirements = cycle.completed_requirements.deep_dup

      Prosopite.pause do
        Telephone::MAX_OTP_ATTEMPTS.times do
          patch sign_app_sign_up_check_telephone_otp_url(ri: "jp"), params: {
            user_telephone: { pass_code: "000000" },
          }
        end
      end

      assert_response :too_many_requests
      assert_includes response.body, I18n.t("sign.app.registration.telephone.update.attempts_exceeded")
      assert_empty flash.to_hash

      assert ClientTelephone.exists?(telephone.id)
      assert Client.exists?(user.id)
      assert_predicate telephone.reload, :locked?
      assert_nil session[:user_telephone_registration]
      assert_equal completed_requirements, cycle.reload.completed_requirements
      assert_nil cycle.completed_requirements["otp"]
    end

    test "should cleanup existing unverified telephones on create" do
      # Create first registration
      post sign_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567894",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      first_telephone = registration_telephone
      first_user = first_telephone.user

      travel CommonOtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second do
        # Create second registration with the same number
        post sign_app_sign_up_telephone_url, params: {
          user_telephone: {
            raw_number: "+1234567894",
            confirm_policy: "1",
            confirm_using_mfa: "1",
          },
          "cf-turnstile-response": "test",
        }
      end

      # First telephone and its pending user should be cleaned up
      assert_not ClientTelephone.exists?(first_telephone.id)
      assert_not Client.exists?(first_user.id)
    end

    test "create rejects duplicate unverified telephone inside overwrite window" do
      post sign_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567895",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      first_telephone = registration_telephone
      first_user = first_telephone.user

      assert_no_difference("ClientTelephone.count") do
        assert_no_difference("Client.count") do
          post sign_app_sign_up_telephone_url, params: {
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
      assert ClientTelephone.exists?(first_telephone.id)
      assert Client.exists?(first_user.id)
    end

    test "resend sends code for active registration session" do
      post sign_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      registration_telephone

      assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
        post sign_app_sign_up_check_telephone_otp_url(ri: "jp")
      end

      assert_redirected_to sign_app_sign_up_check_telephone_otp_url(ri: "jp")
      assert_predicate session[:user_telephone_otp_last_sent_at], :present?
    end

    test "resend returns success even without registration session" do
      assert_no_difference("ClientTelephone.count") do
        assert_enqueued_jobs 0, only: Outbound::SmsDeliveryJob do
          post sign_app_sign_up_check_telephone_otp_url(ri: "jp")
        end
      end

      assert_response :unprocessable_content
      assert_equal "ticket is required", response.body
    end

    test "resend rate limits repeated requests" do
      post sign_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567890",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }
      registration_telephone

      assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
        post sign_app_sign_up_check_telephone_otp_url(ri: "jp")
      end
      assert_enqueued_jobs 0, only: Outbound::SmsDeliveryJob do
        post sign_app_sign_up_check_telephone_otp_url(ri: "jp")
      end

      assert_response :too_many_requests
      assert_includes response.body, I18n.t("sign.app.registration.email.create.otp_resend_too_soon")
    end

    test "resend cooldown is 30 seconds" do
      post sign_app_sign_up_telephone_url, params: {
        user_telephone: {
          raw_number: "+1234567892",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        },
        "cf-turnstile-response": "test",
      }

      assert_response :redirect

      post sign_app_sign_up_check_telephone_otp_url(ri: "jp")
      sent_at = session[:user_telephone_otp_last_sent_at]
      telephone = registration_telephone
      otp_data = telephone.get_otp
      cycle = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
      completed_requirements = cycle.completed_requirements.deep_dup

      assert_predicate sent_at, :present?
      assert_redirected_to sign_app_sign_up_check_telephone_otp_url(ri: "jp")

      travel 29.seconds do
        assert_enqueued_jobs 0, only: Outbound::SmsDeliveryJob do
          post sign_app_sign_up_check_telephone_otp_url(ri: "jp")
        end
        assert_response :too_many_requests
        assert_includes response.body, I18n.t("sign.app.registration.email.create.otp_resend_too_soon")
        assert_equal sent_at, session[:user_telephone_otp_last_sent_at]
        assert_equal otp_data, telephone.reload.get_otp
        assert_equal completed_requirements, cycle.reload.completed_requirements
      end

      travel 31.seconds do
        assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
          post sign_app_sign_up_check_telephone_otp_url(ri: "jp")
        end
        assert_redirected_to sign_app_sign_up_check_telephone_otp_url(ri: "jp")
        assert_operator session[:user_telephone_otp_last_sent_at], :>, sent_at
      end
    end

    private

    def regional_defaults
      { ri: "jp" }
    end

    def registration_telephone
      registration_session = session[:user_telephone_registration] || {}
      public_id = registration_session[:public_id] || registration_session["public_id"]
      ClientTelephone.find_by!(public_id: public_id)
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
