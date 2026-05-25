# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      module Emails
        class RegistrationsController < ::Sign::Org::PrivateController
          include ::CloudflareTurnstile
          include ::Common::Otp
          include ::Verification::Operator

          before_action :authenticate_operator!
          before_action only: %i(new create edit update) do
            require_step_up!(scope: verification_scope)
          end

          def new
            @staff_email = OperatorEmail.new
          end

          def edit
            @staff_email = current_registration_email
            return if valid_registration_session?

            reset_registration_session!
            redirect_to(
              new_sign_org_configuration_emails_registration_path,
              notice: t("sign.org.registration.email.edit.session_expired"),
            )
          end

          def create
            email_params = params(staff_email: %i(raw_address address notifiable))
            email_address = email_params[:raw_address] || email_params[:address]
            email_preferences = email_params.slice(:notifiable)
            @staff_email = current_operator.staff_emails.build(
              { raw_address: email_address, confirm_policy: "1" }.merge(email_preferences),
            )
            @staff_email.staff_email_status_id = OperatorEmailStatus::UNVERIFIED

            unless cloudflare_turnstile_stealth_validation["success"]
              @staff_email.errors.add(:base, t("sign.org.registration.email.create.turnstile_validation_failed"))
              render :new, status: :unprocessable_content
              return
            end

            otp_code = generate_otp_attributes(@staff_email)
            unless @staff_email.save
              render :new, status: :unprocessable_content
              return
            end

            Email::Org::OtpMailer.with(
              encrypted_hotp_token: Outbound::SensitivePayload.encrypt_email_otp(otp_code),
              email_address: @staff_email.address,
              verification_token: nil,
              public_id: @staff_email.public_id,
            ).create.deliver_later

            session[registration_session_key] = @staff_email.public_id
            redirect_to(
              edit_sign_org_configuration_emails_registration_path,
              notice: t("sign.org.registration.email.create.verification_code_sent"),
            )
          end

          def update
            @staff_email = current_registration_email
            unless valid_registration_session?
              reset_registration_session!
              redirect_to(
                new_sign_org_configuration_emails_registration_path,
                notice: t("sign.org.registration.email.edit.session_expired"),
              )
              return
            end

            unless cloudflare_turnstile_stealth_validation["success"]
              @staff_email.errors.add(:base, t("turnstile_error"))
              flash.now[:alert] = t("turnstile_error")
              render(:edit, status: :unprocessable_content)
              return
            end

            submitted_code = params.dig(:staff_email, :pass_code)
            if submitted_code.blank?
              @staff_email.errors.add(:pass_code, t("sign.org.registration.email.update.code_required"))
              render :edit, status: :unprocessable_content
              return
            end

            result = verify_otp_code(@staff_email, submitted_code)
            unless result[:success]
              increment_otp_attempts!(@staff_email)
              if @staff_email.locked?
                @staff_email.destroy!
                reset_registration_session!
                redirect_to(
                  new_sign_org_configuration_emails_registration_path,
                  alert: t("sign.org.registration.email.update.attempts_exceeded"),
                )
                return
              end

              @staff_email.errors.add(:pass_code, t("sign.org.registration.email.update.invalid_code"))
              render :edit, status: :unprocessable_content
              return
            end

            clear_otp(@staff_email)
            @staff_email.update!(staff_email_status_id: OperatorEmailStatus::VERIFIED)
            reset_registration_session!

            redirect_to(
              bootstrap_return_path(sign_org_configuration_emails_path),
              notice: t("sign.org.registration.email.update.success"),
            )
          end

          private

          def current_registration_email
            current_operator.staff_emails.find_by(public_id: session[registration_session_key])
          end

          def valid_registration_session?
            @staff_email.present? &&
              !@staff_email.otp_expired? &&
              @staff_email.staff_email_status_id == OperatorEmailStatus::UNVERIFIED
          end

          def registration_session_key
            :staff_email_registration_public_id
          end

          def reset_registration_session!
            session.delete(registration_session_key)
          end

          def verification_required_action?
            true
          end

          def verification_scope
            "configuration_email"
          end
        end
      end
    end
  end
end
