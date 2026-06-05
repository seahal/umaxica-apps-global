# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      class EmailsController < Sign::App::ApplicationController
        include ::CloudflareTurnstile
        include Common::Redirect
        include Common::Otp
        include Sign::EmailRegistrable

        AUTHENTICATION_MODE = :guest
        before_action :enforce_email_flow!

        declare_authentication_mode! :guest, status: :unauthorized,
                                             message: I18n.t("errors.messages.already_authenticated"),
                                             no_redirect: true

        # Defence-in-depth for sign-up entry. The default IP limit is 300/min
        # which is too generous for an OTP-generating endpoint. Tighten to
        # 5/min per IP and 3/10min per email digest to slow address
        # enumeration and OTP fanout from a single source.
        rate_limit(
          to: 5,
          within: 1.minute,
          by: -> { "sign_up_email_ip:#{request.remote_ip}" },
          with: -> { handle_rate_limit_exceeded!("sign_up_email_ip", 60) },
          store: RateLimit.store,
          only: :create,
        )
        rate_limit(
          to: 3,
          within: 10.minutes,
          by: -> {
            digest = sign_up_email_digest_for_rate_limit
            digest.present? ? "sign_up_email_addr:#{digest}" : "sign_up_email_addr:none"
          },
          with: -> { handle_rate_limit_exceeded!("sign_up_email_addr", 600) },
          store: RateLimit.store,
          only: :create,
        )

        def new
          @user_email = ClientEmail.new
          sign_up_flow_locator.clear!
        end

        def edit
          @user_email = current_registration_email

          # Security: Verify email exists and belongs to current session
          if @user_email.blank?
            reset_email_flow!
            redirect_to(
              new_sign_app_up_email_path,
              notice: t("sign.app.registration.email.edit.not_found"),
            )
            return
          end

          # Security: Validate the email belongs to the current registration flow
          return if valid_email_session?

          reset_email_flow!
          redirect_params = build_notice_params(t("sign.app.registration.email.edit.session_expired"))
          flash[:notice] = redirect_params.delete(:notice)
          redirect_to(new_sign_app_up_email_path(redirect_params))
          nil
        end

        def create
          unless cloudflare_turnstile_validation["success"]
            @user_email = ClientEmail.new
            @user_email.errors.add(
              :base, t("sign.app.registration.email.create.turnstile_validation_failed"),
            )
            render :new, status: :unprocessable_content
            return
          end

          email_params = params.permit(
            user_email: %i(raw_address address confirm_policy promotional notifiable),
          )[:user_email]
          email_address = email_params&.[](:raw_address).presence || email_params&.[](:address).presence

          if email_address.blank?
            @user_email = ClientEmail.new
            @user_email.errors.add(
              :base, t("sign.app.registration.email.create.address_required"),
            )
            render :new, status: :unprocessable_content
            return
          end

          result = initiate_email_verification!(
            email_address,
            confirm_policy: email_params[:confirm_policy],
            allow_existing: true,
            email_preferences: email_params.slice(:promotional, :notifiable),
          )

          if result == :cooldown
            render plain: t("sign.app.registration.email.create.otp_resend_too_soon"),
                   status: :too_many_requests
            return
          end

          unless result
            log_signup_email_errors
            strip_user_owner_errors!
            render :new, status: :unprocessable_content
            return
          end

          bind_sign_up_flow_to_email!(@user_email)
          progress_email_flow!(:create)
          redirect_params = build_notice_params(t("sign.app.registration.email.create.verification_code_sent"))
          flash[:notice] = redirect_params.delete(:notice)
          sanitize_redirect_params!(redirect_params)
          redirect_to(edit_sign_app_up_email_path(redirect_params))
        end

        def update
          @user_email =
            if defined?(Prosopite)
              Prosopite.pause { current_registration_email }
            else
              current_registration_email
            end

          return redirect_invalid_session unless valid_email_session?
          return render_code_required unless validate_code_present

          result = process_verification_code
          return if result == :redirected

          return handle_locked_result if result == :locked
          return render :edit, status: :unprocessable_content unless result

          complete_update_and_redirect
        end

        private

        def redirect_invalid_session
          reset_email_flow!
          redirect_params = build_notice_params(t("sign.app.registration.email.edit.session_expired"))
          flash[:notice] = redirect_params.delete(:notice)
          redirect_to(new_sign_app_up_email_path(redirect_params))
        end

        def validate_code_present
          params.dig("user_email", "pass_code").present?
        end

        def render_code_required
          @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.code_required"))
          render :edit, status: :unprocessable_content
        end

        def process_verification_code
          submitted_code = params.dig("user_email", "pass_code")
          if existing_signup_email_flow?
            handle_existing_email_verification(submitted_code)
          else
            if defined?(Prosopite)
              Prosopite.pause do
                complete_email_verification!(@user_email.public_id, submitted_code) do |user_email|
                  prepare_email_for_checkpoint!(user_email)
                end
              end
            else
              complete_email_verification!(@user_email.public_id, submitted_code) do |user_email|
                prepare_email_for_checkpoint!(user_email)
              end
            end
          end
        end

        def handle_locked_result
          reset_email_flow!
          flash[:alert] = t("sign.app.registration.email.update.attempts_exceeded")
          redirect_to(new_sign_app_up_email_path)
        end

        def complete_update_and_redirect
          progress_email_flow!(:update)
          advance_sign_up_flow_after_email_otp!
          redirect_to(
            sign_app_up_guard_path(
              ri: params[:ri],
              pt: signed_pt_token(path_target_value),
            ),
            notice: t("sign.app.registration.email.update.success"),
          )
        end

        def sanitize_redirect_params!(redirect_params)
          return if redirect_params[:pt].blank?

          redirect_params[:pt] = sanitize_encoded_redirect(redirect_params[:pt])
          redirect_params.delete(:pt) if redirect_params[:pt].blank?
        end

        def sanitize_encoded_redirect(encoded_url)
          signed_pt_token(encoded_url)
        end

        def valid_email_session?
          return false if @user_email.blank?

          if existing_signup_email_flow?
            return false unless Integer(session_existing_email_id.to_s, 10) == @user_email.id

            existing_signup_skip_otp? || !@user_email.otp_expired?
          else
            return false if @user_email.otp_expired?

            @user_email.user_email_status_id == ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP
          end
        end

        def existing_signup_email_flow?
          session_existing_email_id.present?
        end

        def session_existing_email_id
          session[Sign::EmailRegistrable::EXISTING_EMAIL_SESSION_KEY]
        end

        def existing_signup_skip_otp?
          session[Sign::EmailRegistrable::EXISTING_EMAIL_SKIP_OTP_SESSION_KEY] == true
        end

        def handle_existing_email_verification(submitted_code)
          if existing_signup_skip_otp?
            reset_email_flow!
            redirect_to(
              new_sign_app_sign_in_path,
              notice: t("sign.app.registration.email.update.sign_in_required"),
            )
            return :redirected
          end

          result = verify_otp_code(@user_email, submitted_code)
          unless result[:success]
            increment_otp_attempts!(@user_email)
            if @user_email.locked?
              reset_email_flow!
              return :locked
            end

            @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.invalid_code"))
            return false
          end

          clear_otp(@user_email)
          reset_email_flow!
          session.delete(Sign::EmailRegistrable::EXISTING_EMAIL_SESSION_KEY)
          redirect_to(
            new_sign_app_sign_in_path,
            notice: t("sign.app.registration.email.update.sign_in_required"),
          )
          :redirected
        end

        def prepare_email_for_checkpoint!(user_email)
          user_email.save!
        end

        def log_signup_email_errors
          return unless @user_email&.errors&.any?

          Rails.logger.warn(
            Jit::LogEvent.format(
              "sign.signup.email.validation_failed",
              errors: @user_email.errors.full_messages,
            ),
          )
        end

        def strip_user_owner_errors!
          return if @user_email.blank?

          @user_email.errors.delete(:user)
          @user_email.errors.delete(:user_id)
        end

        def current_registration_email
          if existing_signup_email_flow?
            return ClientEmail.find_by(id: session_existing_email_id)
          end

          pending_user_id = session[:pending_sign_up_user_id]
          return if pending_user_id.blank?

          ClientEmail.find_by(
            user_id: pending_user_id,
            user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
          )
        end

        # Derives a per-address rate-limit bucket. Uses the same SHA-256
        # digest the model stores so concurrent normalisations resolve to
        # the same bucket. Returns nil for blank input — the rate_limit
        # lambda decides how to handle that case.
        def sign_up_email_digest_for_rate_limit
          raw = params.dig(:user_email, :raw_address) ||
            params.dig(:user_email, :address) ||
            params.dig(:visitor_email, :raw_address) ||
            params.dig(:visitor_email, :address)
          return nil if raw.blank?

          normalized = raw.to_s.strip.downcase
          Digest::SHA256.hexdigest(normalized)
        end

        def issue_sign_up_flow!
          AppTicketRecord.connected_to(role: :writing) do
            ClientSignUpFlowStatus.ensure_defaults!
          end

          sign_up_flow_locator.issue!(
            ClientSignUpFlow.create!(
              principal_id: nil,
              status_id: ClientSignUpFlowStatus::STARTED,
              step: "start",
              nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
              issued_at: Time.current,
              expires_at: ClientSignUpFlow.default_ttl.from_now,
              entry_method: "email",
              return_to: sanitized_return_to,
            ),
          )
        end

        def current_sign_up_flow
          sign_up_flow_locator.current || issue_sign_up_flow!
        end

        def bind_sign_up_flow_to_email!(email)
          cycle = current_sign_up_flow
          AppTicketRecord.connected_to(role: :writing) do
            cycle.update!(
              principal_id: email.user_id,
              pending_contact_type: "email",
              pending_contact_id: email.id,
            )
            SignUp::StateMachine.call(ticket: cycle, event: :submit_contact, actor_context: Actor.authn)
          end
          session[:sign_app_up_sequence_id] = cycle.public_id
        end

        def advance_sign_up_flow_after_email_otp!
          cycle = sign_up_flow_locator.current
          return unless cycle

          result =
            AppTicketRecord.connected_to(role: :writing) do
              SignUp::StateMachine.call(ticket: cycle, event: :verify_contact, actor_context: Actor.authn)
            end
          return if result.status == :advanced

          Rails.logger.warn(
            Jit::LogEvent.format(
              "sign.signup.email.sequence_advance_failed",
              cycle_id: cycle.public_id,
              result_status: result.status,
              errors: result.errors,
            ),
          )
        end

        def sign_up_flow_locator
          SignUp::CycleLocator.new(session, surface: :app, cycle_class: ClientSignUpFlow)
        end

        def sanitized_return_to
          resolved_path_or_navigation_target
        end
      end
    end
  end
end
