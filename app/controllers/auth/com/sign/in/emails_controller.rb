# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module In
        class EmailsController < ::Auth::Com::ApplicationController
          include ::CloudflareTurnstile

          include EmailValidation

          include CommonRedirect

          include CommonOtp

          include SessionLimitGate

          AUTHENTICATION_MODE = :guest

          rate_limit(
            to: 5,
            within: 1.minute,
            by: -> { request.remote_ip },
            scope: "auth_com_sign_in",
            name: "email_create_ip_burst",
            store: rate_limit_store,
            only: :create,
            with: -> { render_rate_limited(rule_name: "auth_com_sign_in_email_create_ip_burst", retry_after: 60) },
          )
          rate_limit(
            to: 20,
            within: 15.minutes,
            by: -> { request.remote_ip },
            scope: "auth_com_sign_in",
            name: "email_create_ip_sustained",
            store: rate_limit_store,
            only: :create,
            with: -> { render_rate_limited(rule_name: "auth_com_sign_in_email_create_ip_sustained", retry_after: 900) },
          )
          declare_authentication_mode!(
            :guest,
            status: :bad_request,
            message: I18n.t("sign.app.authentication.email.new.you_have_already_logged_in"),
            no_redirect: true,
          )

          before_action :load_user_email, only: :edit

          def identity_email_model
            VisitorEmail
          end

          def new
            @user_email = VisitorEmail.new
          end

          def edit
          end

          def create
            address_params = params.permit(user_email: [:address])[:user_email] || {}
            address = address_params[:address]
            unless cloudflare_turnstile_validation["success"] && address.present?
              @user_email = VisitorEmail.new(address: address)
              return render :new, status: :unprocessable_content
            end

            normalized_address = validate_and_normalize_email(address)
            unless normalized_address
              @user_email = VisitorEmail.new(address: address)
              @user_email.errors.add(:address, t("sign.app.authentication.email.create.invalid_format"))
              return render :new, status: :unprocessable_content
            end

            if sign_in_email_cooldown_active?(normalized_address)
              # One message for every address. Branching on whether the account exists
              # would turn the cooldown response into an account-existence oracle,
              # which is exactly what the dummy OTP work below exists to prevent.
              render plain: t("sign.app.authentication.email.create.cooldown"), status: :too_many_requests
              return
            end

            result = process_email_authentication(normalized_address)

            if result == :cooldown
              render plain: t("sign.app.authentication.email.create.cooldown"), status: :too_many_requests
              return
            end

            return render_session_limit_hard_reject if @session_limit_hard_reject

            record_sign_in_email_cooldown!(normalized_address)
            preserve_pt

            redirect_to(edit_auth_com_sign_in_email_path(pt: peek_pt, ri: current_region_identifier))
          end

          private

          def load_user_email
            if session[:user_email_authentication_id].present?
              @user_email = load_session_record(
                :user_email_authentication_id,
                VisitorEmail,
                check_otp_expiry: false,
                custom: ->(email) { email.present? && !email.otp_expired? },
              )

              unless @user_email
                redirect_to(new_auth_com_sign_in_email_path(pt: peek_pt, ri: current_region_identifier))
                return
              end
              @otp_resend_state = SignInOtpResendState.issue(kind: :email, target: @user_email.address)
            elsif session[:user_email_authentication_address].present?
              @user_email = VisitorEmail.new(address: session[:user_email_authentication_address])
              @otp_resend_state = SignInOtpResendState.issue(
                kind: :email,
                target: session[:user_email_authentication_address],
              )
            else
              redirect_to(new_auth_com_sign_in_email_path(pt: peek_pt, ri: current_region_identifier))
            end
          end

          def process_email_authentication(normalized_address)
            existing_email = find_email_with_timing_protection(normalized_address)

            if existing_email&.visitor&.login_allowed?
              visitor = existing_email.visitor
              if session_limit_hard_reject_for?(visitor)
                @session_limit_hard_reject = true
                return
              end

              session[:user_email_authentication_id] = existing_email.id
              session[:user_email_authentication_address] = nil

              return :ok if existing_email.locked?
              return :cooldown if otp_request_rate_limited?(existing_email)

              otp_code = generate_otp_for(existing_email)

              OtpAdapter.for(surface: :com, channel: :email).deliver(
                record: existing_email,
                otp_code: otp_code,
              )
            else
              perform_dummy_otp_generation

              session[:user_email_authentication_id] = nil
              session[:user_email_authentication_address] = normalized_address
            end

            :ok
          end

          def otp_request_rate_limited?(user_email)
            user_email.otp_cooldown_active?
          end

          def sign_in_email_cooldown_active?(normalized_address)
            return false if session[:sign_in_email_cooldown_address] != normalized_address

            last_sent_at = session[:sign_in_email_cooldown_at]
            return false if last_sent_at.blank?

            last_sent_at.to_i > CommonOtpPolicy::SEND_COOLDOWN.ago.to_i
          end

          def record_sign_in_email_cooldown!(normalized_address)
            session[:sign_in_email_cooldown_address] = normalized_address
            session[:sign_in_email_cooldown_at] = Time.current.to_i
          end
        end
      end
    end
  end
end
