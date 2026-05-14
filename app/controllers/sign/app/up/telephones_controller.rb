# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      class TelephonesController < ApplicationController
        include CloudflareTurnstile
        include Common::Redirect
        include Common::Otp

        guest_only! status: :unauthorized

        def new
          @user_telephone = UserTelephone.new

          # to avoid session attack
          session[:user_telephone_registration] = nil
        end

        def edit
          @user_telephone = UserTelephone.find_by(public_id: params["id"])
          return if valid_telephone_session?

          redirect_to(
            new_sign_app_up_telephone_path,
            notice: t("sign.app.registration.telephone.edit.session_expired"),
          )
        end

        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        def create
          telephone_params = params.fetch(:user_telephone, {}).permit(
            :raw_number, :number, :confirm_policy, :confirm_using_mfa,
          )

          if telephone_params.blank?
            @user_telephone = UserTelephone.new
            @user_telephone.errors.add(:raw_number, :blank)
            render :new, status: :unprocessable_content
            return
          end

          @user_telephone = UserTelephone.new(telephone_params || {})

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
              existing_telephone.user_telephone_status_id != UserTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
            if existing_telephone.locked?
              render plain: t("sign.app.registration.email.create.otp_resend_too_soon"), status: :too_many_requests
              return
            end

            cleanup_pending_telephone_signup!
            dispatch_existing_telephone_verification!(existing_telephone)
            return
          end

          if existing_telephone&.locked?
            render plain: t("sign.app.registration.email.create.otp_resend_too_soon"), status: :too_many_requests
            return
          end

          if existing_telephone&.user_telephone_status_id == UserTelephoneStatus::UNVERIFIED_WITH_SIGN_UP &&
              existing_telephone.reregistration_window_active?
            render plain: t("sign.app.registration.email.create.otp_resend_too_soon"), status: :too_many_requests
            return
          end

          begin
            UserTelephone.transaction do
              # Cleanup pending signup from same session
              cleanup_pending_telephone_signup!

              locked_existing = UserTelephone.lock.find_by(id: existing_telephone.id) if existing_telephone
              if locked_existing&.user_telephone_status_id == UserTelephoneStatus::UNVERIFIED_WITH_SIGN_UP &&
                  locked_existing.reregistration_window_active?
                render plain: t("sign.app.registration.email.create.otp_resend_too_soon"), status: :too_many_requests
                raise ActiveRecord::Rollback
              end

              if locked_existing&.locked?
                render plain: t("sign.app.registration.email.create.otp_resend_too_soon"), status: :too_many_requests
                raise ActiveRecord::Rollback
              end

              # Remove existing unverified telephones with same number
              remove_existing_unverified_telephones!

              # Create pending user
              @pending_user = User.create!(status_id: UserStatus::UNVERIFIED_WITH_SIGN_UP)
              @user_telephone.user = @pending_user
              @user_telephone.user_telephone_status_id = UserTelephoneStatus::UNVERIFIED_WITH_SIGN_UP

              # Generate OTP
              num = generate_otp_attributes(@user_telephone)
              expires_at = @user_telephone.otp_expires_at
              @user_telephone.otp_last_sent_at = Time.current if @user_telephone.respond_to?(:otp_last_sent_at=)

              @user_telephone.save!

              # Store public_id and expiry in session
              session[:user_telephone_registration] = {
                public_id: @user_telephone.public_id,
                confirm_policy: boolean_value(@user_telephone.confirm_policy),
                confirm_using_mfa: boolean_value(@user_telephone.confirm_using_mfa),
                expires_at: expires_at.to_i,
              }

              # Send SMS with OTP
              SmsDeliveryJob.perform_later(
                to: @user_telephone.number,
                message: "PassCode => #{num}",
                subject: "PassCode => #{num}",
              )

              redirect_to(
                edit_sign_app_up_telephone_path(@user_telephone),
                notice: t("sign.app.registration.telephone.create.verification_code_sent"),
              )
            end
          rescue ActiveRecord::RecordInvalid => e
            @user_telephone = e.record
            log_signup_telephone_errors
            render :new, status: :unprocessable_content
          end
        end

        # rubocop:enable Metrics/MethodLength

        def update
          @user_telephone = UserTelephone.find_by(public_id: params["id"])

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

          verify_telephone!
          if sms_login_ready?
            complete_sms_login!
          else
            finalize_telephone_registration!
          end
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
            SmsDeliveryJob.perform_later(
              to: @user_telephone.number,
              message: "PassCode => #{otp_code}",
              subject: "PassCode => #{otp_code}",
            )
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
            @user_telephone.user_telephone_status_id == UserTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
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

        def render_telephone_session_expired
          @user_telephone.errors.add(:base, t("sign.app.registration.telephone.edit.session_expired"))
          render :edit, status: :unprocessable_content
        end

        def valid_registration_session?(registration_session)
          session_public_id = session_public_id_from_registration(registration_session)
          registration_session.present? &&
            session_public_id.to_s == params.expect(:id).to_s
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

        def verify_telephone!
          UserTelephone.transaction do
            # Clear OTP (set confirm flags to avoid validation errors)
            @user_telephone.confirm_policy = "1"
            @user_telephone.confirm_using_mfa = "1"
            clear_otp(@user_telephone)
            # Update status
            @user_telephone.user_telephone_status_id = UserTelephoneStatus::VERIFIED_WITH_SIGN_UP
            @user_telephone.save!
          end
        end

        def finalize_telephone_registration!
          redirect_to(
            sign_app_up_telephone_passkey_registration_path(@user_telephone, ri: params[:ri]),
            notice: t("sign.app.registration.telephone.update.passkey_required"),
          )
        end

        def sms_login_ready?
          user = @user_telephone.user
          return false unless user

          user.user_passkeys.active.exists?
        end

        def complete_sms_login!
          user = @user_telephone.user
          return finalize_telephone_registration! unless user

          User.transaction do
            if user.status_id == UserStatus::UNVERIFIED_WITH_SIGN_UP
              user.update!(status_id: UserStatus::VERIFIED_WITH_SIGN_UP)
            end
            user.create_user_account! unless user.user_account

            # Audit record
            audit = UserChronicle.new
            audit.actor_type = "User"
            audit.actor_id = user.id
            audit.event_id = UserChronicleEvent::SIGNED_UP_WITH_TELEPHONE
            audit.subject_id = user.id.to_s
            audit.subject_type = "User"
            audit.save!
          end

          log_in(
            user,
            record_login_audit: true,
            audit_context: { auth_method: "telephone" },
          )
          session[:user_telephone_registration] = nil
          create_welcome_bulletin!(current_resource)
          redirect_to_sign_in_sequence!(
            rt: redirect_parameter_value,
            notice: t("sign.app.registration.telephone.update.success"),
          )
        end

        def otp_resend_rate_limited?
          last_sent_at = session[:user_telephone_otp_last_sent_at]
          return false if last_sent_at.blank?

          last_sent_at.to_i > Common::OtpPolicy::SEND_COOLDOWN.ago.to_i
        end

        def load_registration_telephone(registration_session)
          return nil if registration_session.blank?

          public_id = registration_session[:public_id] || registration_session["public_id"]
          UserTelephone.find_by(public_id: public_id)
        end

        def resend_redirect_path
          if @user_telephone
            edit_sign_app_up_telephone_path(@user_telephone, ri: params[:ri])
          else
            new_sign_app_up_telephone_path(ri: params[:ri])
          end
        end

        def cleanup_pending_telephone_signup!
          pending_public_id =
            session.dig(:user_telephone_registration, "public_id") ||
            session.dig(:user_telephone_registration, :public_id)
          return if pending_public_id.blank?

          pending_telephone = UserTelephone.find_by(public_id: pending_public_id)
          return unless pending_telephone

          pending_user = pending_telephone.user
          pending_telephone.destroy!
          pending_user.destroy! if pending_user&.status_id == UserStatus::UNVERIFIED_WITH_SIGN_UP
        end

        def remove_existing_unverified_telephones!
          return if @user_telephone.number_digest.blank?

          existing_telephones = UserTelephone.where(
            number_digest: @user_telephone.number_digest,
            user_identity_telephone_status_id: [
              UserTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
            ],
          ).to_a

          pending_user_ids = existing_telephones.filter_map(&:user_id)
          if pending_user_ids.any?
            User.where(id: pending_user_ids, status_id: UserStatus::UNVERIFIED_WITH_SIGN_UP)
              .find_each(&:destroy!)
          end
          existing_telephones.each(&:destroy!)
        end

        def existing_signup_telephone_flow?(registration_session)
          registration_session&.dig(:existing) == true || registration_session&.dig("existing") == true
        end

        def dispatch_existing_telephone_verification!(existing_telephone)
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

          SmsDeliveryJob.perform_later(
            to: @user_telephone.number,
            message: "PassCode => #{otp_code}",
            subject: "PassCode => #{otp_code}",
          )

          redirect_to(
            edit_sign_app_up_telephone_path(@user_telephone, ri: params[:ri]),
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

          Rails.event.warn(
            "sign.signup.telephone.validation_failed",
            errors: @user_telephone.errors.full_messages,
          )
        end

        def find_existing_telephone_by_digest
          return nil if @user_telephone.number_digest.blank?

          UserTelephone.find_by(number_digest: @user_telephone.number_digest)
        end
      end
    end
  end
end
