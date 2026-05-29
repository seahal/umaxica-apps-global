# typed: false
# frozen_string_literal: true

module Sign
  module App
    module In
      class EmailsController < Sign::App::ApplicationController
        include ::CloudflareTurnstile

        include EmailValidation

        include Common::Redirect

        include Common::Otp

        include SessionLimitGate

        AUTHENTICATION_MODE = :guest

        declare_authentication_mode!(
          :guest,
          status: :bad_request,
          message: I18n.t("sign.app.authentication.email.new.you_have_already_logged_in"),
          no_redirect: true,
        )

        before_action :load_user_email, only: %i(edit update)

        def new
          @user_email = ClientEmail.new
        end

        def edit
        end

        def create
          address_params = params.permit(user_email: [:address])[:user_email] || {}
          address = address_params[:address]
          unless cloudflare_turnstile_validation["success"] && address.present?
            @user_email = ClientEmail.new(address: address)
            return render :new, status: :unprocessable_content
          end

          normalized_address = validate_and_normalize_email(address)
          unless normalized_address
            @user_email = ClientEmail.new(address: address)
            @user_email.errors.add(:address, t("sign.app.authentication.email.create.invalid_format"))
            return render :new, status: :unprocessable_content
          end

          if sign_in_email_cooldown_active?(normalized_address)
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

          # Preserve pt parameter if provided
          preserve_pt

          flash[:notice] = t("sign.app.authentication.email.create.verification_code_sent")
          redirect_to(edit_sign_app_in_email_path(pt: peek_pt))
        end

        def update
          # Record start time for timing attack mitigation
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          @user_email.pass_code = update_pass_code_params[:pass_code]

          unless @user_email.valid?
            respond_to do |format|
              format.html { render :edit, status: :unprocessable_content }
              format.json {
                render json: { error: @user_email.errors.full_messages.join(", ") },
                       status: :unprocessable_content
              }
            end
            return
          end

          result = verify_otp_and_login(@user_email)
          ensure_min_elapsed(start_time)

          if result[:success]
            respond_to_successful_email_login(result)
          elsif result[:hard_reject]
            render_session_limit_hard_reject(
              message: result[:error],
              http_status: result[:http_status],
            )
          else
            respond_to_failed_email_login(result)
          end
        end

        private

        def respond_to_successful_email_login(result)
          respond_to do |format|
            format.html { redirect_after_successful_email_login(result) }
            format.json { render_successful_email_login_json(result) }
          end
        end

        def redirect_after_successful_email_login(result)
          if result[:restricted]
            redirect_to(result[:redirect_path], notice: I18n.t("sign.app.in.session.restricted_notice"))
          elsif result[:redirect_path]
            redirect_to(result[:redirect_path], notice: t("sign.app.in.mfa.required"))
          else
            redirect_to_sign_in_sequence!(
              pt: retrieve_pt,
              notice: t("sign.app.authentication.email.update.success"),
            )
          end
        end

        def render_successful_email_login_json(result)
          if result[:restricted]
            render json: {
              status: "session_restricted",
              redirect_url: result[:redirect_path],
              message: I18n.t("sign.app.in.session.restricted_notice"),
            }, status: :ok
          else
            render json: result[:tokens], status: :ok
          end
        end

        def respond_to_failed_email_login(result)
          @user_email.errors.add(:pass_code, result[:error])
          respond_to do |format|
            format.html { render :edit, status: :unprocessable_content }
            format.json { render json: { error: result[:error] }, status: :unprocessable_content }
          end
        end

        def handle_guest_only_with_status_checks(options)
          if options[:no_redirect]
            status = options[:status] || :forbidden
            message = options[:message] || I18n.t("errors.messages.already_authenticated")
            return render plain: message, status: status
          end

          super
        end

        def load_user_email
          state = email_authentication_state
          return redirect_to_email_session_expired if state.nil?

          if state.existing?
            @user_email = find_existing_email_for_verification(state.id)
            return redirect_to_email_session_expired if @user_email.nil?

            @otp_resend_state = Sign::In::OtpResendState.issue(kind: :email, target: @user_email.address)
          else
            @user_email = ClientEmail.new(address: state.address)
            @otp_resend_state = Sign::In::OtpResendState.issue(kind: :email, target: state.address)
          end
        end

        def email_authentication_state
          Sign::App::In::EmailAuthenticationState.load(session)
        end

        def find_existing_email_for_verification(id)
          scope = ClientEmail.includes(:user_email_status, :user)
          email = defined?(Prosopite) ? Prosopite.pause { scope.find_by(id: id) } : scope.find_by(id: id)
          return nil if email.blank? || email.otp_expired?

          email
        end

        def redirect_to_email_session_expired
          flash[:notice] = t("sign.app.authentication.email.edit.session_expired")
          redirect_to(new_sign_app_in_email_path(pt: peek_pt))
        end

        def process_email_authentication(normalized_address)
          existing_email = find_email_with_timing_protection(normalized_address)

          if existing_email&.user&.login_allowed?
            # Pre-check session limit before sending OTP.
            # If the user is already at the hard limit (2 active + 1 restricted),
            # skip sending OTP and flag for the create action to handle.
            user = existing_email.user
            if session_limit_hard_reject_for?(user)
              @session_limit_hard_reject = true
              return
            end

            Sign::App::In::EmailAuthenticationState.store_existing!(session, existing_email)

            return :ok if existing_email.locked?
            return :cooldown if otp_request_rate_limited?(existing_email)

            otp_code = generate_otp_for(existing_email)

            Email::App::OtpMailer.with(
              encrypted_hotp_token: Outbound::SensitivePayload.encrypt_email_otp(otp_code),
              email_address: existing_email.address,
            ).create.deliver_later
          else
            # Dummy work to simulate OTP generation for timing attack protection
            perform_dummy_otp_generation

            Sign::App::In::EmailAuthenticationState.store_dummy!(session, normalized_address)
          end

          :ok
        end

        def verify_otp_and_login(user_email)
          state = email_authentication_state
          if state&.existing?
            verify_existing_email_otp(user_email)
          else
            verify_dummy_otp(user_email)
          end
        end

        def verify_existing_email_otp(user_email)
          result = verify_otp_code(user_email, user_email.pass_code)

          if result[:success]
            user = user_from_user_email(user_email)
            unless user&.login_allowed?
              return { success: false, error: t("sign.app.authentication.email.update.invalid_code") }
            end

            clear_otp(user_email)
            Sign::App::In::EmailAuthenticationState.clear!(session)
            pt = peek_pt
            result = establish_signed_in_session!(
              user, pt: pt, ri: params[:ri], auth_method: "email",
            )
            sign_in_result = sign_in_result_from_session_result(result, actor: user)
            if sign_in_result.mfa_required?
              { success: true, redirect_path: sign_in_result.redirect_to }
            elsif sign_in_result.status == :session_limit_hard_reject
              { success: false,
                error: sign_in_result.message,
                hard_reject: true,
                http_status: sign_in_result.response_status, }
            elsif sign_in_result.session_limit_pending?
              { success: true, restricted: true, redirect_path: sign_in_result.redirect_to }
            elsif sign_in_result.success?
              { success: true, tokens: sign_in_result.token }
            else
              { success: false, error: t("sign.app.authentication.email.update.invalid_code") }
            end
          else
            user = user_from_user_email(user_email)
            increment_otp_attempts!(user_email)
            handle_failed_otp_attempt(user_email, user)
          end
        end

        def verify_dummy_otp(user_email)
          # Perform timing attack protection
          super(user_email.pass_code)
          { success: false, error: t("sign.app.authentication.email.update.invalid_code") }
        end

        def handle_failed_otp_attempt(user_email, user = nil)
          user ||= user_from_user_email(user_email)
          audit_client_login_failed(user) if user
          Sign::Risk::Emitter.emit("auth_failed", user_id: user&.id) if user

          if user_email.locked?
            { success: false, error: email_locked_message }
          else
            remaining = [Email::MAX_OTP_ATTEMPTS - user_email.otp_attempts_count, 0].max
            { success: false,
              error: t("sign.app.authentication.email.update.invalid_code", attempts_left: remaining), }
          end
        end

        def update_pass_code_params
          params(user_email: [:pass_code])
        rescue ActionController::ParameterMissing
          {}
        end

        def user_from_user_email(user_email)
          return user_email.user if user_email.association(:user).loaded?

          operation = -> { Client.find_by(id: user_email.user_id) }
          defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
        end

        def otp_request_rate_limited?(user_email)
          return false unless user_email.otp_cooldown_active?

          true
        end

        def sign_in_email_cooldown_active?(normalized_address)
          return false if session[:sign_in_email_cooldown_address] != normalized_address

          last_sent_at = session[:sign_in_email_cooldown_at]
          return false if last_sent_at.blank?

          last_sent_at.to_i > Common::OtpPolicy::SEND_COOLDOWN.ago.to_i
        end

        def record_sign_in_email_cooldown!(normalized_address)
          session[:sign_in_email_cooldown_address] = normalized_address
          session[:sign_in_email_cooldown_at] = Time.current.to_i
        end

        def email_locked_message
          t("sign.app.authentication.email.locked", default: t("errors.otp_locked"))
        end
      end
    end
  end
end
