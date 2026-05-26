# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module In
      class EmailsController < GuestController
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

          flash[:notice] = t("sign.app.authentication.email.create.verification_code_sent")
          redirect_to(edit_sign_com_in_email_path(pt: peek_pt, ri: params[:ri]))
        end

        def update
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          @user_email.pass_code = update_pass_code_params[:pass_code]

          unless @user_email.valid?
            respond_to do |format|
              format.html { render :edit, status: :unprocessable_content }
              format.json do
                render json: { error: @user_email.errors.full_messages.join(", ") }, status: :unprocessable_content
              end
            end
            return
          end

          result = verify_otp_and_login(@user_email)
          ensure_min_elapsed(start_time)

          if result[:success]
            handle_update_success(result)
          else
            handle_update_failure(result)
          end
        end

        def handle_update_success(result)
          respond_to do |format|
            format.html { handle_html_success(result) }
            format.json { handle_json_success(result) }
          end
        end

        def handle_html_success(result)
          if result[:restricted]
            redirect_to(result[:redirect_path], notice: I18n.t("sign.app.in.session.restricted_notice"))
          elsif result[:redirect_path]
            redirect_to(result[:redirect_path], notice: t("sign.app.in.mfa.required"))
          else
            pt_param = retrieve_pt
            redirect_to_sign_in_sequence!(
              pt: pt_param,
              notice: t("sign.app.authentication.email.update.success"),
            )
          end
        end

        def handle_json_success(result)
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

        def handle_update_failure(result)
          if result[:hard_reject]
            render_session_limit_hard_reject(message: result[:error], http_status: result[:http_status])
          else
            @user_email.errors.add(:pass_code, result[:error])
            respond_to do |format|
              format.html { render :edit, status: :unprocessable_content }
              format.json { render json: { error: result[:error] }, status: :unprocessable_content }
            end
          end
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
              flash[:notice] = t("sign.app.authentication.email.edit.session_expired")
              redirect_to(new_sign_com_in_email_path(pt: peek_pt, ri: params[:ri]))
              return
            end
            @otp_resend_state = Sign::In::OtpResendState.issue(kind: :email, target: @user_email.address)
          elsif session[:user_email_authentication_address].present?
            @user_email = VisitorEmail.new(address: session[:user_email_authentication_address])
            @otp_resend_state = Sign::In::OtpResendState.issue(
              kind: :email,
              target: session[:user_email_authentication_address],
            )
          else
            flash[:notice] = t("sign.app.authentication.email.edit.session_expired")
            redirect_to(new_sign_com_in_email_path(pt: peek_pt, ri: params[:ri]))
          end
        end

        def process_email_authentication(normalized_address)
          existing_email = find_email_with_timing_protection(normalized_address)

          Rails.logger.debug { "Inside controller existing_email: #{existing_email.inspect}" }
          Rails.logger.debug { "Inside controller identity_email_model: #{identity_email_model}" }
          Rails.logger.debug { "Inside controller login_allowed: #{existing_email&.visitor&.login_allowed?}" }

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

            Email::Com::OtpMailer.with(
              encrypted_hotp_token: Outbound::SensitivePayload.encrypt_email_otp(otp_code),
              email_address: existing_email.address,
            ).create.deliver_later
          else
            perform_dummy_otp_generation

            session[:user_email_authentication_id] = nil
            session[:user_email_authentication_address] = normalized_address
          end

          :ok
        end

        def verify_otp_and_login(user_email)
          if session[:user_email_authentication_id].present?
            verify_existing_email_otp(user_email)
          else
            verify_dummy_otp(user_email)
          end
        end

        def verify_existing_email_otp(user_email)
          result = verify_otp_code(user_email, user_email.pass_code)

          if result[:success]
            visitor = visitor_from_visitor_email(user_email)
            unless visitor&.login_allowed?
              return { success: false, error: t("sign.app.authentication.email.update.invalid_code") }
            end

            clear_otp(user_email)
            session[:user_email_authentication_id] = nil
            pt = peek_pt
            result = establish_signed_in_session!(visitor, pt: pt, ri: params[:ri], auth_method: "email")
            sign_in_result = sign_in_result_from_session_result(result, actor: visitor)

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
            increment_otp_attempts!(user_email)
            visitor = visitor_from_visitor_email(user_email)
            handle_failed_otp_attempt(user_email, visitor)
          end
        end

        def verify_dummy_otp(user_email)
          super(user_email.pass_code)
          { success: false, error: t("sign.app.authentication.email.update.invalid_code") }
        end

        def handle_failed_otp_attempt(user_email, visitor = nil)
          visitor ||= visitor_from_visitor_email(user_email)
          audit_visitor_login_failed(visitor) if visitor
          Sign::Risk::Emitter.emit("auth_failed", visitor_id: visitor&.id) if visitor

          if user_email.locked?
            { success: false, error: email_locked_message }
          else
            { success: false, error: t("sign.app.authentication.email.update.invalid_code") }
          end
        end

        def visitor_from_visitor_email(visitor_email)
          return unless visitor_email
          return visitor_email.visitor if visitor_email.association(:visitor).loaded?

          if defined?(Prosopite)
            Prosopite.pause { visitor_email.visitor }
          else
            visitor_email.visitor
          end
        end

        def update_pass_code_params
          params(user_email: [:pass_code])
        rescue ActionController::ParameterMissing
          {}
        end

        def otp_request_rate_limited?(user_email)
          user_email.otp_cooldown_active?
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
