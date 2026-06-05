# typed: false
# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength

module Sign
  module Com
    module Up
      class EmailsController < Sign::Com::ApplicationController
        include ::CloudflareTurnstile

        include Common::Redirect

        include Common::Otp

        AUTHENTICATION_MODE = :guest

        SESSION_KEY = :sign_com_up_email_flow_state
        EXISTING_EMAIL_SESSION_KEY = :sign_com_up_existing_visitor_email_id
        EXISTING_EMAIL_SKIP_OTP_SESSION_KEY = :sign_com_up_existing_visitor_email_skip_otp
        PENDING_VISITOR_ID_SESSION_KEY = :sign_com_up_pending_visitor_id

        before_action :enforce_email_flow!

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
          @user_email = VisitorEmail.new
          sign_up_flow_locator.clear!
        end

        def edit
          @user_email = current_registration_email
          if @user_email.blank?
            reset_email_flow!
            redirect_to(
              new_sign_com_up_email_path(ri: params[:ri]),
              notice: t("sign.app.registration.email.edit.not_found"),
            )
            return
          end

          return if valid_email_session?

          reset_email_flow!
          flash[:notice] = t("sign.app.registration.email.edit.session_expired")
          redirect_to(new_sign_com_up_email_path(ri: params[:ri]))
        end

        def create
          unless cloudflare_turnstile_validation["success"]
            @user_email = VisitorEmail.new
            @user_email.errors.add(
              :base,
              t("sign.com.registration.email.create.turnstile_validation_failed"),
            )
            render :new, status: :unprocessable_content
            return
          end

          email_params = params.permit(visitor_email: %i(raw_address address confirm_policy notifiable))[:visitor_email]
          email_address = email_params&.[](:raw_address).presence || email_params&.[](:address).presence

          if email_address.blank?
            @user_email = VisitorEmail.new
            @user_email.errors.add(
              :base,
              t("sign.com.registration.email.create.address_required"),
            )
            render :new, status: :unprocessable_content
            return
          end

          result = initiate_visitor_email_verification!(
            email_address,
            confirm_policy: email_params[:confirm_policy],
            email_preferences: email_params.slice(:notifiable),
          )
          if result == :cooldown
            render plain: t("sign.app.registration.email.create.otp_resend_too_soon"), status: :too_many_requests
            return
          end

          unless result
            strip_visitor_owner_errors!
            render :new, status: :unprocessable_content
            return
          end

          bind_sign_up_flow_to_email!(@user_email) unless existing_signup_email_flow?
          progress_email_flow!(:create)
          flash[:notice] = t("sign.com.registration.email.create.verification_code_sent")
          redirect_to(edit_sign_com_up_email_path(ri: params[:ri], pt: sanitized_rt_param))
        end

        def update
          @user_email = current_registration_email
          return redirect_invalid_session unless valid_email_session?
          return render_code_required if params.dig("visitor_email", "pass_code").blank?

          submitted_code = params.dig("visitor_email", "pass_code")
          result =
            existing_signup_email_flow? ? handle_existing_email_verification(submitted_code) :
                                           complete_visitor_email_verification!(submitted_code)
          return if result == :redirected
          return handle_locked_result if result == :locked
          return redirect_invalid_session if result == :invalid_session
          return render :edit, status: :unprocessable_content unless result

          progress_email_flow!(:update)
          redirect_to(
            sign_com_up_guard_path(
              ri: params[:ri],
              pt: signed_pt_token(path_target_value),
            ),
            notice: t("sign.app.registration.email.update.success"),
          )
        end

        private

        def enforce_email_flow!
          requirements = { new: "init", create: "init", edit: "email_created", update: "email_created" }
          required = requirements[action_name.to_sym]
          return unless required

          current = email_flow_state
          if %i(new create).include?(action_name.to_sym) && current != "init"
            reset_email_flow!
            return
          end
          return if current == required

          flash[:alert] = t("sign.app.registration.email.flow.invalid")
          redirect_to(new_sign_com_up_email_path(ri: params[:ri]))
        end

        def email_flow_state
          state = session[SESSION_KEY].to_s
          state = "init" unless %w(init email_created email_verified).include?(state)
          session[SESSION_KEY] = state
        end

        def progress_email_flow!(action)
          next_state = { create: "email_created", update: "email_verified" }[action.to_sym]
          session[SESSION_KEY] = next_state if next_state
        end

        def reset_email_flow!
          session[SESSION_KEY] = "init"
          session.delete(EXISTING_EMAIL_SESSION_KEY)
          session.delete(EXISTING_EMAIL_SKIP_OTP_SESSION_KEY)
          session.delete(PENDING_VISITOR_ID_SESSION_KEY)
          sign_up_flow_locator.clear!
        end

        def redirect_invalid_session
          reset_email_flow!
          flash[:notice] = t("sign.app.registration.email.edit.session_expired")
          redirect_to(new_sign_com_up_email_path(ri: params[:ri]))
        end

        def render_code_required
          @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.code_required"))
          render :edit, status: :unprocessable_content
        end

        def handle_locked_result
          reset_email_flow!
          flash[:alert] = t("sign.app.registration.email.update.attempts_exceeded")
          redirect_to(new_sign_com_up_email_path(ri: params[:ri]))
        end

        def valid_email_session?
          return false if @user_email.blank?

          if existing_signup_email_flow?
            return false unless Integer(session_existing_email_id.to_s, 10) == @user_email.id

            existing_signup_skip_otp? || !@user_email.otp_expired?
          else
            return false if @user_email.otp_expired?

            @user_email.visitor_email_status_id == VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP
          end
        end

        def existing_signup_email_flow?
          session_existing_email_id.present?
        end

        def session_existing_email_id
          session[EXISTING_EMAIL_SESSION_KEY]
        end

        def existing_signup_skip_otp?
          session[EXISTING_EMAIL_SKIP_OTP_SESSION_KEY] == true
        end

        def initiate_visitor_email_verification!(email_address, confirm_policy: "1", email_preferences: {})
          @user_email = VisitorEmail.new(
            { raw_address: email_address, confirm_policy: confirm_policy }.merge(email_preferences),
          )
          @user_email.visitor_email_status_id = VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP
          @user_email.validate

          # Without a deterministic lock keyed on the address digest, two
          # sessions submitting the same address can both pass the existence
          # check below and race the unique index on `save!`, leaving the
          # loser with a generic uniqueness validation error. The advisory
          # lock serializes the existence-check-then-create sequence per
          # email digest.
          return false if @user_email.address_digest.blank?

          SignUp::EmailPendingGuard.with_lock(
            address_digest: @user_email.address_digest,
            model_class: VisitorEmail,
          ) do
            existing_email = VisitorEmail.find_by(address_digest: @user_email.address_digest)
            uniqueness_only = visitor_email_uniqueness_only_error?(@user_email)

            if existing_email &&
                existing_email.visitor_email_status_id != VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP &&
                (uniqueness_only || @user_email.errors.empty?)
              @user_email = existing_email
              session[EXISTING_EMAIL_SESSION_KEY] = @user_email.id
              session[EXISTING_EMAIL_SKIP_OTP_SESSION_KEY] = true
              next true
            end

            if existing_email&.visitor_email_status_id == VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP &&
                existing_email.reregistration_window_active?
              next :cooldown
            end

            next false if @user_email.errors.details.except(:visitor, :visitor_id).any? && !uniqueness_only

            cleanup_pending_visitor_signup!
            remove_existing_unverified_visitor_emails!
            pending_visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
            session[PENDING_VISITOR_ID_SESSION_KEY] = pending_visitor.id
            @user_email.visitor = pending_visitor
            otp_number = generate_otp_attributes(@user_email)
            @user_email.otp_last_sent_at = Time.current
            @user_email.save!
            token = @user_email.generate_verification_token
            Email::Com::OtpMailer.with(
              encrypted_hotp_token: Outbound::SensitivePayload.encrypt_email_otp(otp_number),
              email_address: @user_email.address,
              verification_token: token, public_id: @user_email.public_id,
            ).create.deliver_later

            true
          end
        rescue ActiveRecord::RecordInvalid => e
          @user_email = e.record if e.record.is_a?(VisitorEmail)
          strip_visitor_owner_errors!
          false
        end

        def complete_visitor_email_verification!(submitted_code)
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

          sequence_advanced = false
          VisitorEmail.transaction do
            clear_otp(@user_email)
            @user_email.update!(visitor_email_status_id: VisitorEmailStatus::VERIFIED_WITH_SIGN_UP)
            sequence_advanced = advance_sign_up_flow_after_email_otp!
            raise ActiveRecord::Rollback unless sequence_advanced
          end

          sequence_advanced ? true : :invalid_session
        end

        def handle_existing_email_verification(submitted_code)
          if existing_signup_skip_otp?
            reset_email_flow!
            redirect_to(
              new_sign_com_sign_in_path(ri: params[:ri]),
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
          session.delete(EXISTING_EMAIL_SESSION_KEY)
          redirect_to(
            new_sign_com_sign_in_path(ri: params[:ri]),
            notice: t("sign.app.registration.email.update.sign_in_required"),
          )
          :redirected
        end

        def cleanup_pending_visitor_signup!
          pending_visitor_id = session[PENDING_VISITOR_ID_SESSION_KEY]
          return if pending_visitor_id.blank?

          Visitor.find_by(id: pending_visitor_id)&.destroy!
        end

        def remove_existing_unverified_visitor_emails!
          return if @user_email.address_digest.blank?

          existing_emails = VisitorEmail.where(address_digest: @user_email.address_digest, visitor_email_status_id: [VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP]).to_a
          pending_visitor_ids = existing_emails.filter_map(&:visitor_id)
          Visitor.where(id: pending_visitor_ids).find_each(&:destroy!) if pending_visitor_ids.any?
          existing_emails.each { |email| email.destroy! if email.visitor_id.blank? }
        end

        def visitor_email_uniqueness_only_error?(visitor_email)
          errors_to_check = visitor_email.errors.details.except(:visitor, :visitor_id)
          return false if errors_to_check.empty?

          uniqueness_fields = %i(address raw_address address_digest)
          errors_to_check.each do |field, errors|
            return false unless uniqueness_fields.include?(field)
            return false unless errors.all? { |error| error[:error] == :taken }
          end
          visitor_email.errors.details.any?
        end

        def sanitized_rt_param
          signed_pt_token(path_target_value)
        end

        # Derives a per-address rate-limit bucket. Uses the same SHA-256
        # digest the model stores so concurrent normalisations resolve to
        # the same bucket. Returns nil for blank input — the rate_limit
        # lambda decides how to handle that case.
        def sign_up_email_digest_for_rate_limit
          raw = params.dig(:visitor_email, :raw_address) ||
            params.dig(:visitor_email, :address) ||
            params.dig(:user_email, :raw_address) ||
            params.dig(:user_email, :address)
          return nil if raw.blank?

          normalized = raw.to_s.strip.downcase
          Digest::SHA256.hexdigest(normalized)
        end

        def strip_visitor_owner_errors!
          return if @user_email.blank?

          @user_email.errors.delete(:visitor)
          @user_email.errors.delete(:visitor_id)
        end

        def current_registration_email
          if existing_signup_email_flow?
            return VisitorEmail.find_by(id: session_existing_email_id)
          end

          pending_visitor_id = session[PENDING_VISITOR_ID_SESSION_KEY]
          return if pending_visitor_id.blank?

          VisitorEmail.find_by(
            visitor_id: pending_visitor_id,
            visitor_email_status_id: VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP,
          )
        end

        def issue_sign_up_flow!
          ComTicketRecord.connected_to(role: :writing) do
            VisitorSignUpFlowStatus.ensure_defaults!
          end

          sign_up_flow_locator.issue!(
            VisitorSignUpFlow.create!(
              principal_id: nil,
              status_id: VisitorSignUpFlowStatus::STARTED,
              step: "start",
              nonce_digest: VisitorSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
              issued_at: Time.current,
              expires_at: VisitorSignUpFlow.default_ttl.from_now,
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
          ComTicketRecord.connected_to(role: :writing) do
            cycle.update!(
              principal_id: email.visitor_id,
              pending_contact_type: "email",
              pending_contact_id: email.id,
            )
            SignUp::StateMachine.call(ticket: cycle, event: :submit_contact, actor_context: Actor.authn)
          end
          session[:sign_com_up_sequence_id] = cycle.public_id
        end

        def advance_sign_up_flow_after_email_otp!
          cycle = sign_up_flow_locator.current
          return false unless cycle

          result =
            ComTicketRecord.connected_to(role: :writing) do
              SignUp::StateMachine.call(ticket: cycle, event: :verify_contact, actor_context: Actor.authn)
            end
          result.status == :advanced
        end

        def sign_up_flow_locator
          SignUp::CycleLocator.new(session, surface: :com, cycle_class: VisitorSignUpFlow)
        end

        def sanitized_return_to
          resolved_path_or_navigation_target
        end
      end
    end
  end
end
