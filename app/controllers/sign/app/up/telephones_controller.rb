# typed: false
# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength

module Sign
  module App
    module Up
      class TelephonesController < Sign::App::ApplicationController
        include CloudflareTurnstile

        include Common::Redirect

        include Common::Otp

        AUTHENTICATION_MODE = :guest

        declare_authentication_mode! :guest, status: :unauthorized,
                                             message: I18n.t("errors.messages.already_authenticated"),
                                             no_redirect: true

        def new
          @user_telephone = ClientTelephone.new

          # to avoid session attack
          session[:user_telephone_registration] = nil
          sign_up_cycle_locator.clear!
        end

        def edit
          @user_telephone = current_registration_telephone
          return if valid_telephone_session?

          redirect_to(
            new_sign_app_up_telephone_path,
            notice: t("sign.app.registration.telephone.edit.session_expired"),
          )
        end

        def create
          ensure_signup_reference_defaults!

          telephone_params = params.fetch(:user_telephone, {}).permit(
            :raw_number, :number, :confirm_policy, :confirm_using_mfa,
          )

          if telephone_params.blank?
            @user_telephone = ClientTelephone.new
            @user_telephone.errors.add(:raw_number, :blank)
            render :new, status: :unprocessable_content
            return
          end

          @user_telephone = ClientTelephone.new(telephone_params || {})

          res = cloudflare_turnstile_validation

          unless res["success"]
            @user_telephone.errors.add(
              :base,
              t("sign.app.registration.telephone.create.turnstile_validation_failed"),
            )
            render :new, status: :unprocessable_content
            return
          end

          @user_telephone.validate

          existing_telephone = find_existing_telephone_by_digest
          uniqueness_only = telephone_uniqueness_only_error?(@user_telephone)

          has_errors = @user_telephone.errors.details.except(:user, :user_id).any?

          if has_errors && !uniqueness_only
            log_signup_telephone_errors
            render :new, status: :unprocessable_content
            return
          end

          if existing_telephone &&
              existing_telephone.user_telephone_status_id != ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
            if existing_telephone.locked?
              return render_otp_resend_too_soon
            end

            cleanup_pending_telephone_signup!
            dispatch_existing_telephone_verification!(existing_telephone)
            return
          end

          if existing_telephone&.locked?
            return render_otp_resend_too_soon
          end

          if existing_telephone&.user_telephone_status_id == ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP &&
              existing_telephone.reregistration_window_active?
            return render_otp_resend_too_soon
          end

          begin
            result = Sign::App::Up::TelephoneSignupCreator.call(
              telephone: @user_telephone,
              existing_telephone: existing_telephone,
              pending_public_id: session_public_id_from_registration,
            )

            if result.status == :rate_limited
              return render_otp_resend_too_soon
            end

            @user_telephone = result.telephone
            session[:user_telephone_registration] = result.session_payload
            bind_sign_up_cycle_to_telephone!(@user_telephone)
            redirect_to(
              edit_sign_app_up_telephone_path,
              notice: t("sign.app.registration.telephone.create.verification_code_sent"),
            )
          rescue ActiveRecord::RecordInvalid => e
            @user_telephone = e.record
            log_signup_telephone_errors
            render :new, status: :unprocessable_content
          end
        end

        def update
          @user_telephone = current_registration_telephone

          return redirect_telephone_session_expired unless @user_telephone

          registration_session = session[:user_telephone_registration]
          return render_telephone_session_expired unless valid_registration_session?(registration_session)
          return render_telephone_session_expired if otp_session_expired?(registration_session)

          # Blank code check
          submitted_code = params.dig("user_telephone", "pass_code")
          if submitted_code.blank?
            @user_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.code_required"))
            render :edit, status: :unprocessable_content
            return
          end

          existing_flow = existing_signup_telephone_flow?(registration_session)

          # Verify OTP code with lockout handling
          verification_result =
            if existing_flow
              verify_existing_telephone_code
            else
              verify_submitted_telephone_code
            end
          if verification_result == :locked
            flash[:alert] = t("sign.app.registration.telephone.update.attempts_exceeded")
            redirect_to(new_sign_app_up_telephone_path(ri: params[:ri]))
            return
          end
          return render_invalid_telephone_code unless verification_result

          if existing_flow
            clear_otp(@user_telephone)
            session[:user_telephone_registration] = nil
            redirect_to(
              new_sign_app_in_path,
              notice: t("sign.app.registration.telephone.update.sign_in_required"),
            )
            return
          end

          verify_telephone_ownership!
          advance_sign_up_cycle_after_telephone_otp!
          redirect_to(
            sign_app_up_guardrail_path(ri: params[:ri]),
            notice: t("sign.app.registration.telephone.update.passkey_required"),
          )
        end

        def resend
          registration_session = session[:user_telephone_registration]
          @user_telephone = load_registration_telephone(registration_session)

          if otp_resend_rate_limited?
            flash[:alert] = t("sign.app.registration.telephone.resend.rate_limited")
            return redirect_to(resend_redirect_path)
          end

          if @user_telephone
            otp_code = generate_otp_for(@user_telephone)
            Sign::TelephoneOtpDelivery.deliver!(@user_telephone, otp_code)
          else
            perform_dummy_otp_generation
          end

          session[:user_telephone_otp_last_sent_at] = Time.current.to_i
          redirect_to(
            resend_redirect_path,
            notice: t("sign.app.registration.telephone.resend.sent"),
          )
        end

        private

        def valid_telephone_session?
          return false unless @user_telephone.present? && !@user_telephone.otp_expired?

          if existing_signup_telephone_flow?(session[:user_telephone_registration])
            session_public_id = session_public_id_from_registration
            session_public_id.to_s == @user_telephone.public_id.to_s
          else
            @user_telephone.user_telephone_status_id == ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
          end
        end

        def boolean_value(value)
          ActiveModel::Type::Boolean.new.cast(value)
        end

        def redirect_telephone_session_expired
          redirect_to(
            new_sign_app_up_telephone_path,
            notice: t("sign.app.registration.telephone.edit.session_expired"),
          )
        end

        def render_otp_resend_too_soon
          render plain: t("sign.app.registration.email.create.otp_resend_too_soon"), status: :too_many_requests
        end

        def render_telephone_session_expired
          @user_telephone.errors.add(:base, t("sign.app.registration.telephone.edit.session_expired"))
          render :edit, status: :unprocessable_content
        end

        def valid_registration_session?(registration_session)
          session_public_id = session_public_id_from_registration(registration_session)
          registration_session.present? &&
            session_public_id.to_s == @user_telephone.public_id.to_s
        end

        def session_public_id_from_registration(registration_session = session[:user_telephone_registration])
          registration_session&.dig("public_id") || registration_session&.dig(:public_id)
        end

        def otp_session_expired?(registration_session)
          @user_telephone.otp_expired? ||
            registration_session["expires_at"].to_i <= Time.current.to_i
        end

        def verify_submitted_telephone_code
          submitted_code = params.dig("user_telephone", "pass_code")
          result = verify_otp_code(@user_telephone, submitted_code)
          return true if result[:success]

          increment_otp_attempts!(@user_telephone)

          if @user_telephone.locked?
            session[:user_telephone_registration] = nil
            return :locked
          end

          @user_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.invalid_code"))
          false
        end

        def verify_existing_telephone_code
          submitted_code = params.dig("user_telephone", "pass_code")
          result = verify_otp_code(@user_telephone, submitted_code)
          return true if result[:success]

          increment_otp_attempts!(@user_telephone)
          return :locked if @user_telephone.locked?

          @user_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.invalid_code"))
          false
        end

        def render_invalid_telephone_code
          render :edit, status: :unprocessable_content
        end

        # OTP success only proves telephone ownership for the current sign-up
        # cycle. It must NOT mark the telephone durably VERIFIED_WITH_SIGN_UP:
        # passkey setup is still required, and a durable verified row that
        # survives abandonment would block re-registration of the same number
        # (the pending-signup cleanup only collects UNVERIFIED rows).
        #
        # The proof is scoped to the registration session and consumed by the
        # passkey step. The durable transition happens in
        # Sign::App::Up::TelephoneRegistrationFinalizer after passkey setup.
        def verify_telephone_ownership!
          @user_telephone.confirm_policy = "1"
          @user_telephone.confirm_using_mfa = "1"
          clear_otp(@user_telephone)
          @user_telephone.save! if @user_telephone.changed?

          registration = (session[:user_telephone_registration] || {}).dup
          registration["otp_verified"] = true
          registration["public_id"] ||= @user_telephone.public_id
          session[:user_telephone_registration] = registration
        end

        def otp_resend_rate_limited?
          last_sent_at = session[:user_telephone_otp_last_sent_at]
          return false if last_sent_at.blank?

          last_sent_at.to_i > Common::OtpPolicy::SEND_COOLDOWN.ago.to_i
        end

        def load_registration_telephone(registration_session)
          return nil if registration_session.blank?

          public_id = registration_session[:public_id] || registration_session["public_id"]
          ClientTelephone.find_by(public_id: public_id)
        end

        def resend_redirect_path
          if @user_telephone
            edit_sign_app_up_telephone_path(ri: params[:ri])
          else
            new_sign_app_up_telephone_path(ri: params[:ri])
          end
        end

        def cleanup_pending_telephone_signup!
          pending_public_id =
            session.dig(:user_telephone_registration, "public_id") ||
            session.dig(:user_telephone_registration, :public_id)
          sign_up_cycle_locator.clear!
          return if pending_public_id.blank?

          pending_telephone = ClientTelephone.find_by(public_id: pending_public_id)
          return unless pending_telephone

          pending_user = pending_telephone.user
          pending_telephone.destroy!
          pending_user.destroy! if pending_user&.status_id == ClientStatus::UNVERIFIED_WITH_SIGN_UP
        end

        def existing_signup_telephone_flow?(registration_session)
          registration_session&.dig(:existing) == true || registration_session&.dig("existing") == true
        end

        def dispatch_existing_telephone_verification!(existing_telephone)
          sign_up_cycle_locator.clear!
          @user_telephone = existing_telephone
          otp_code = generate_otp_for(@user_telephone)
          @user_telephone.update!(otp_last_sent_at: Time.current) if @user_telephone.respond_to?(:otp_last_sent_at=)

          session[:user_telephone_registration] = {
            public_id: @user_telephone.public_id,
            confirm_policy: boolean_value(@user_telephone.confirm_policy),
            confirm_using_mfa: boolean_value(@user_telephone.confirm_using_mfa),
            expires_at: @user_telephone.otp_expires_at.to_i,
            existing: true,
          }

          Sign::TelephoneOtpDelivery.deliver!(@user_telephone, otp_code)

          redirect_to(
            edit_sign_app_up_telephone_path(ri: params[:ri]),
            notice: t("sign.app.registration.telephone.create.verification_code_sent"),
          )
        end

        def telephone_uniqueness_only_error?(user_telephone)
          # ignore :user and :user_id error
          errors_to_check = user_telephone.errors.details.except(:user, :user_id)
          return false if errors_to_check.empty?

          # Fields that can have uniqueness errors
          uniqueness_fields = %i(number raw_number number_digest)

          # Check if all errors are :taken errors on the uniqueness fields
          errors_to_check.each do |field, errors|
            return false unless uniqueness_fields.include?(field)
            return false unless errors.all? { |error| error[:error] == :taken }
          end

          # Ensure at least one uniqueness error is present
          user_telephone.errors.details.any?
        end

        def log_signup_telephone_errors
          return unless @user_telephone&.errors&.any?

          Rails.logger.warn(
            LogEvent.format(
              "sign.signup.telephone.validation_failed",
              errors: @user_telephone.errors.full_messages,
            ),
          )
        end

        def find_existing_telephone_by_digest
          return nil if @user_telephone.number_digest.blank?

          ClientTelephone.find_by(number_digest: @user_telephone.number_digest)
        end

        def issue_sign_up_cycle!
          AppTicketRecord.connected_to(role: :writing) do
            ClientSignUpCycleStatus.ensure_defaults!
          end

          sign_up_cycle_locator.issue!(
            ClientSignUpCycle.create!(
              principal_id: nil,
              status_id: ClientSignUpCycleStatus::STARTED,
              step: "start",
              nonce_digest: ClientSignUpCycle.digest_nonce(SecureRandom.urlsafe_base64(32)),
              issued_at: Time.current,
              expires_at: ClientSignUpCycle.default_ttl.from_now,
              entry_method: "telephone",
            ),
          )
        end

        def current_sign_up_cycle
          sign_up_cycle_locator.current || issue_sign_up_cycle!
        end

        def bind_sign_up_cycle_to_telephone!(telephone)
          cycle = current_sign_up_cycle
          cycle.update!(
            principal_id: telephone.user_id,
            pending_contact_type: "telephone",
            pending_contact_id: telephone.id,
          )
          SignUp::StateMachine.call(ticket: cycle, event: :submit_contact, actor_context: Actor.authn)
          session[:sign_app_up_sequence_id] = cycle.public_id
        end

        def advance_sign_up_cycle_after_telephone_otp!
          cycle = sign_up_cycle_locator.current
          return unless cycle

          result = SignUp::StateMachine.call(ticket: cycle, event: :verify_contact, actor_context: Actor.authn)
          return if result.status == :advanced

          Rails.logger.warn(
            LogEvent.format(
              "sign.signup.telephone.sequence_advance_failed",
              cycle_id: cycle.public_id,
              result_status: result.status,
              errors: result.errors,
            ),
          )
        end

        def sign_up_cycle_locator
          SignUp::CycleLocator.new(session, surface: :app, cycle_class: ClientSignUpCycle)
        end

        def ensure_signup_reference_defaults!
          ClientStatus.ensure_defaults!
          ClientVisibility.ensure_defaults!
          ClientMultiFactor.ensure_defaults!
          ClientMultiFactorStatus.ensure_defaults!
          ClientTelephoneStatus.ensure_defaults!
        end

        def current_registration_telephone
          public_id = session_public_id_from_registration
          return if public_id.blank?

          ClientTelephone.find_by(public_id: public_id)
        end
      end
    end
  end
end
