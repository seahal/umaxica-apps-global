# typed: false
# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength

module Sign
  module Com
    module Up
      class TelephonesController < GuestController
        include CloudflareTurnstile
        include Common::Redirect
        include Common::Otp

        def new
          @visitor_telephone = VisitorTelephone.new
          session[:visitor_telephone_registration] = nil
          sign_up_cycle_locator.clear!
        end

        def edit
          @visitor_telephone = current_registration_telephone
          return if valid_telephone_session?

          redirect_to(
            new_sign_com_up_telephone_path,
            notice: t("sign.com.registration.telephone.edit.session_expired"),
          )
        end

        def create
          telephone_params = params.fetch(:visitor_telephone, {}).permit(
            :raw_number, :number, :confirm_policy, :confirm_using_mfa,
          )
          if telephone_params.blank?
            @visitor_telephone = VisitorTelephone.new
            @visitor_telephone.errors.add(:raw_number, :blank)
            render :new, status: :unprocessable_content
            return
          end

          @visitor_telephone = VisitorTelephone.new(telephone_params || {})

          res = cloudflare_turnstile_validation

          unless res["success"]
            @visitor_telephone.errors.add(
              :base,
              t("sign.app.registration.telephone.create.turnstile_validation_failed"),
            )
            render :new, status: :unprocessable_content
            return
          end

          @visitor_telephone.validate

          existing_telephone = find_existing_telephone_by_digest
          uniqueness_only = telephone_uniqueness_only_error?(@visitor_telephone)
          has_errors = @visitor_telephone.errors.details.except(:visitor, :visitor_id).any?

          if has_errors && !uniqueness_only
            render :new, status: :unprocessable_content
            return
          end

          if existing_telephone &&
              existing_telephone.visitor_telephone_status_id != VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
            if existing_telephone.locked?
              return render_otp_resend_too_soon
            end

            dispatch_existing_telephone_verification!(existing_telephone)
            return
          end

          if existing_telephone&.locked?
            return render_otp_resend_too_soon
          end

          if existing_telephone&.visitor_telephone_status_id == VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP &&
              existing_telephone.reregistration_window_active?
            return render_otp_resend_too_soon
          end

          result = Sign::Com::Up::TelephoneSignupCreator.call(
            telephone: @visitor_telephone,
            existing_telephone: existing_telephone,
            pending_public_id: session_public_id_from_registration,
          )

          if result.status == :rate_limited
            return render_otp_resend_too_soon
          end

          @visitor_telephone = result.telephone
          session[:visitor_telephone_registration] = result.session_payload
          bind_sign_up_cycle_to_telephone!(@visitor_telephone)
          redirect_to(
            edit_sign_com_up_telephone_path(ri: params[:ri]),
          )
        rescue ActiveRecord::RecordInvalid
          render :new, status: :unprocessable_content
        end

        def update
          @visitor_telephone = current_registration_telephone
          return redirect_to(new_sign_com_up_telephone_path) unless @visitor_telephone

          registration_session = session[:visitor_telephone_registration]
          return redirect_to(new_sign_com_up_telephone_path) unless valid_registration_session?(registration_session)
          return redirect_to(new_sign_com_up_telephone_path) if otp_session_expired?(registration_session)

          submitted_code = params.dig("visitor_telephone", "pass_code")
          if submitted_code.blank?
            @visitor_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.code_required"))
            render :edit, status: :unprocessable_content
            return
          end

          result = verify_otp_code(@visitor_telephone, submitted_code)
          unless result[:success]
            increment_otp_attempts!(@visitor_telephone)
            if @visitor_telephone.locked?
              session[:visitor_telephone_registration] = nil
              redirect_to(
                new_sign_com_up_telephone_path(ri: params[:ri]),
                alert: t("sign.app.registration.telephone.update.attempts_exceeded"),
              )
              return
            end

            @visitor_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.invalid_code"))
            render :edit, status: :unprocessable_content
            return
          end

          if existing_signup_telephone_flow?(registration_session)
            clear_otp(@visitor_telephone)
            session[:visitor_telephone_registration] = nil
            redirect_to(
              new_sign_com_in_path(ri: params[:ri]),
              notice: t("sign.app.registration.telephone.update.sign_in_required"),
            )
            return
          end

          sequence_advanced = false
          VisitorTelephone.transaction do
            verify_telephone_ownership!
            sequence_advanced = advance_sign_up_cycle_after_telephone_otp!
            raise ActiveRecord::Rollback unless sequence_advanced
          end
          unless sequence_advanced
            session[:visitor_telephone_registration] = nil
            redirect_to(
              new_sign_com_up_telephone_path(ri: params[:ri]),
              notice: t("sign.com.registration.telephone.edit.session_expired"),
            )
            return
          end

          redirect_to(
            sign_com_up_guardrail_path(ri: params[:ri]),
            notice: t("sign.com.registration.telephone.success"),
          )
        end

        private

        def valid_telephone_session?
          return false unless @visitor_telephone.present? && !@visitor_telephone.otp_expired?

          if existing_signup_telephone_flow?(session[:visitor_telephone_registration])
            session_public_id_from_registration.to_s == @visitor_telephone.public_id.to_s
          else
            @visitor_telephone.visitor_telephone_status_id == VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
          end
        end

        def valid_registration_session?(registration_session)
          session_public_id = session_public_id_from_registration(registration_session)
          registration_session.present? &&
            session_public_id.to_s == @visitor_telephone.public_id.to_s
        end

        def session_public_id_from_registration(registration_session = session[:visitor_telephone_registration])
          if registration_session.is_a?(Hash)
            registration_session["public_id"] || registration_session[:public_id]
          else
            registration_session
          end
        end

        def otp_session_expired?(registration_session)
          return @visitor_telephone.otp_expired? unless registration_session.is_a?(Hash)

          @visitor_telephone.otp_expired? ||
            registration_session["expires_at"].to_i <= Time.current.to_i
        end

        def existing_signup_telephone_flow?(registration_session)
          registration_session&.dig(:existing) == true || registration_session&.dig("existing") == true
        end

        def render_otp_resend_too_soon
          render plain: t("sign.app.registration.email.create.otp_resend_too_soon"), status: :too_many_requests
        end

        def telephone_uniqueness_only_error?(visitor_telephone)
          errors_to_check = visitor_telephone.errors.details.except(:visitor, :visitor_id)
          return false if errors_to_check.empty?

          uniqueness_fields = %i(number raw_number number_digest)
          errors_to_check.each do |field, errors|
            return false unless uniqueness_fields.include?(field)
            return false unless errors.all? { |error| error[:error] == :taken }
          end

          visitor_telephone.errors.details.any?
        end

        def find_existing_telephone_by_digest
          return nil if @visitor_telephone.number_digest.blank?

          VisitorTelephone.find_by(number_digest: @visitor_telephone.number_digest)
        end

        def dispatch_existing_telephone_verification!(existing_telephone)
          sign_up_cycle_locator.clear!
          @visitor_telephone = existing_telephone
          otp_number = generate_otp_for(@visitor_telephone)
          if @visitor_telephone.respond_to?(:otp_last_sent_at=)
            @visitor_telephone.update!(otp_last_sent_at: Time.current)
          end

          session[:visitor_telephone_registration] = {
            public_id: @visitor_telephone.public_id,
            confirm_policy: boolean_value(@visitor_telephone.confirm_policy),
            confirm_using_mfa: boolean_value(@visitor_telephone.confirm_using_mfa),
            expires_at: @visitor_telephone.otp_expires_at.to_i,
            existing: true,
          }

          Outbound::Sms.deliver_later(
            to: @visitor_telephone.number,
            title: "PassCode => #{otp_number}",
            body: "PassCode => #{otp_number}",
          )

          redirect_to(
            edit_sign_com_up_telephone_path(ri: params[:ri]),
          )
        end

        def current_registration_telephone
          public_id = session_public_id_from_registration
          return if public_id.blank?

          VisitorTelephone.find_by(public_id: public_id)
        end

        def boolean_value(value)
          ActiveModel::Type::Boolean.new.cast(value)
        end

        def verify_telephone_ownership!
          @visitor_telephone.confirm_policy = "1"
          @visitor_telephone.confirm_using_mfa = "1"
          clear_otp(@visitor_telephone)
          @visitor_telephone.save! if @visitor_telephone.changed?

          registration = (session[:visitor_telephone_registration] || {}).dup
          registration["otp_verified"] = true
          registration["public_id"] ||= @visitor_telephone.public_id
          session[:visitor_telephone_registration] = registration
        end

        def issue_sign_up_cycle!
          ComTicketRecord.connected_to(role: :writing) do
            VisitorSignUpCycleStatus.ensure_defaults!
          end

          sign_up_cycle_locator.issue!(
            VisitorSignUpCycle.create!(
              principal_id: nil,
              status_id: VisitorSignUpCycleStatus::STARTED,
              step: "start",
              nonce_digest: VisitorSignUpCycle.digest_nonce(SecureRandom.urlsafe_base64(32)),
              issued_at: Time.current,
              expires_at: VisitorSignUpCycle.default_ttl.from_now,
              entry_method: "telephone",
            ),
          )
        end

        def current_sign_up_cycle
          sign_up_cycle_locator.current || issue_sign_up_cycle!
        end

        def bind_sign_up_cycle_to_telephone!(telephone)
          cycle = current_sign_up_cycle
          ComTicketRecord.connected_to(role: :writing) do
            cycle.update!(
              principal_id: telephone.visitor_id,
              pending_contact_type: "telephone",
              pending_contact_id: telephone.id,
            )
            SignUp::StateMachine.call(ticket: cycle, event: :submit_contact, actor_context: Actor.authentication)
          end
          session[:sign_com_up_sequence_id] = cycle.public_id
        end

        def advance_sign_up_cycle_after_telephone_otp!
          cycle = sign_up_cycle_locator.current
          return false unless cycle

          result =
            ComTicketRecord.connected_to(role: :writing) do
              SignUp::StateMachine.call(ticket: cycle, event: :verify_contact, actor_context: Actor.authentication)
            end
          result.status == :advanced
        end

        def sign_up_cycle_locator
          SignUp::CycleLocator.new(session, surface: :com, cycle_class: VisitorSignUpCycle)
        end
      end
    end
  end
end
