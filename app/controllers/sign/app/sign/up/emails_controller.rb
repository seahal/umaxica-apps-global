# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Sign
      module Up
        class EmailsController < ::Sign::App::ApplicationController
          include ::CloudflareTurnstile
          include CommonRedirect
          include CommonOtp
          include SignEmailRegistrable

          AUTHENTICATION_MODE = :guest
          REGISTRATION_EMAIL_PERMITTED_KEYS = %i(raw_address address confirm_policy promotional notifiable).freeze
          before_action :enforce_email_flow!

          declare_authentication_mode! :guest, status: :unauthorized,
                                               message: I18n.t("errors.messages.already_authenticated"),
                                               no_redirect: true

          # Defence-in-depth for sign-up entry. Tighten OTP fanout from a single
          # source and from repeated attempts against the same email digest.
          rate_limit(
            to: RateLimitProfiles.interactive_post_ip.to,
            within: RateLimitProfiles.interactive_post_ip.within,
            by: -> { "sign_up_email_ip:#{request.remote_ip}" },
            with: -> {
              render_rate_limited(
                rule_name: "sign_up_email_ip",
                retry_after: RateLimitProfiles.interactive_post_ip.retry_after,
              )
            },
            store: rate_limit_store,
            name: "ip_burst",
            scope: "sign_app_sign_up_email",
            only: :create,
          )
          rate_limit(
            to: RateLimitProfiles.email_address_submit.to,
            within: RateLimitProfiles.email_address_submit.within,
            by: -> {
              digest = sign_up_email_digest_for_rate_limit
              "sign_up_email_addr:#{digest}"
            },
            if: -> { sign_up_email_digest_for_rate_limit.present? },
            with: -> {
              render_rate_limited(
                rule_name: "sign_up_email_addr",
                retry_after: RateLimitProfiles.email_address_submit.retry_after,
              )
            },
            store: rate_limit_store,
            name: "email_sustained",
            scope: "sign_app_sign_up_email",
            only: :create,
          )

          def new
            @user_email = ClientEmail.new
          end

          def edit
            @user_email = current_registration_email

            # Security: Verify email exists and belongs to current session
            if @user_email.blank?
              reset_email_flow!
              redirect_to(
                new_sign_app_sign_up_email_path,
                notice: t("sign.app.registration.email.edit.not_found"),
              )
              return
            end

            # Security: Validate the email belongs to the current registration flow
            return if valid_email_session?

            reset_email_flow!
            redirect_params = build_notice_params(t("sign.app.registration.email.edit.session_expired"))
            flash[:notice] = redirect_params.delete(:notice)
            redirect_to(new_sign_app_sign_up_email_path(redirect_params))
            nil
          end

          def create
            log_sign_signup_event(
              "sign.signup.email.create.received",
              sign_signup_request_flags.merge(step: "email_otp"),
            )

            email_params = registration_email_params
            email_address = email_params&.[](:raw_address).presence || email_params&.[](:address).presence

            if email_address.blank?
              @user_email = ClientEmail.new
              @user_email.errors.add(
                :base, t("sign.app.registration.email.create.address_required"),
              )
              log_sign_signup_event(
                "sign.signup.email.create.rejected",
                sign_signup_request_flags.merge(step: "email_otp", reason: "email_blank").compact,
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
              log_sign_signup_event(
                "sign.signup.email.create.rejected",
                sign_signup_request_flags.merge(step: "email_otp", reason: "unexpected_error").compact,
              )
              render :new, status: :unprocessable_content
              return
            end

            bind_sign_up_flow_to_email!(@user_email) unless dummy_existing_email_flow?
            progress_email_flow!(:create)
            redirect_params = build_notice_params(t("sign.app.registration.email.create.verification_code_sent"))
            flash[:notice] = redirect_params.delete(:notice)
            sanitize_redirect_params!(redirect_params)
            redirect_to(sign_app_sign_up_check_email_otp_path(redirect_params))
          end

          private

          def redirect_invalid_session
            reset_email_flow!
            redirect_params = build_notice_params(t("sign.app.registration.email.edit.session_expired"))
            flash[:notice] = redirect_params.delete(:notice)
            redirect_to(new_sign_app_sign_up_email_path(redirect_params))
          end

          def sanitize_redirect_params!(redirect_params)
            return if redirect_params[:pt].blank?

            redirect_params[:pt] = sanitize_encoded_redirect(redirect_params[:pt])
            redirect_params.delete(:pt) if redirect_params[:pt].blank?
          end

          def sanitize_encoded_redirect(encoded_url)
            signed_pt_token(encoded_url)
          end

          def registration_email_params
            scope = params[:client_email] || params[:user_email]
            return nil if scope.blank?
            return scope.permit(REGISTRATION_EMAIL_PERMITTED_KEYS) if scope.is_a?(ActionController::Parameters)

            ActionController::Parameters.new(scope).permit(REGISTRATION_EMAIL_PERMITTED_KEYS)
          end

          def valid_email_session?
            return dummy_existing_email_session_valid? if dummy_existing_email_flow?
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

          def dummy_existing_email_flow?
            session[SignEmailRegistrable::DUMMY_EXISTING_EMAIL_SESSION_KEY].present?
          end

          def dummy_existing_email_session_valid?
            payload = session[SignEmailRegistrable::DUMMY_EXISTING_EMAIL_SESSION_KEY]
            return false unless payload.is_a?(Hash) && payload["dummy"] == true

            payload["expires_at"].to_i > Time.current.to_i
          end

          def session_existing_email_id
            session[SignEmailRegistrable::EXISTING_EMAIL_SESSION_KEY]
          end

          def existing_signup_skip_otp?
            session[SignEmailRegistrable::EXISTING_EMAIL_SKIP_OTP_SESSION_KEY] == true
          end

          def log_signup_email_errors
            return unless @user_email&.errors&.any?

            Rails.logger.warn(
              JitLogEvent.format(
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
            return ClientEmail.new if dummy_existing_email_flow?

            if existing_signup_email_flow?
              return ClientEmail.find_by(id: session_existing_email_id)
            end

            # Resolve the pending email through the same ticket lookup the step
            # gate uses (`current_sign_up_flow_ticket`), which falls back to the
            # sequence id when the locator session payload is absent or its nonce
            # no longer matches. Using the bare locator here diverged from the
            # gate's ticket resolution and left the email unresolved -- the OTP
            # step then rejected a valid flow as an expired session.
            cycle = current_sign_up_flow_ticket
            return unless cycle&.pending_contact_type == "email"

            ClientEmail.find_by(id: cycle.pending_contact_id)
          end

          def cleanup_pending_signup!
            cycle = sign_up_flow_locator.current
            return unless cycle&.principal_id

            Client.find_by(id: cycle.principal_id, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)&.destroy!
          end

          # Derives a per-address rate-limit bucket. Uses the same SHA-256
          # digest the model stores so concurrent normalisations resolve to
          # the same bucket. Returns nil for blank input -- the rate_limit
          # lambda decides how to handle that case.
          def sign_up_email_digest_for_rate_limit
            raw = params.dig(:client_email, :raw_address) ||
              params.dig(:client_email, :address) ||
              params.dig(:user_email, :raw_address) ||
              params.dig(:user_email, :address) ||
              params.dig(:visitor_email, :raw_address) ||
              params.dig(:visitor_email, :address)
            return nil if raw.blank?

            normalized = JitUtilsEmailValidator.normalize(raw)
            return nil if normalized.blank?

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
              SignUpStateMachine.call(ticket: cycle, event: :submit_contact, actor_context: Actor.authn)
            end
            session[:sign_app_up_sequence_id] = cycle.public_id
          end

          def sign_up_flow_locator
            SignUpCycleLocator.new(session, surface: :app, cycle_class: ClientSignUpFlow)
          end

          def sanitized_return_to
            resolved_path_or_navigation_target
          end
        end
      end
    end
  end
end
