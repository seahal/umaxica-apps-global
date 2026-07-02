# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Settings
      module Emails
        class RegistrationsController < ::Auth::Org::ApplicationController
          include ::CloudflareTurnstile

          include ::CommonOtp
          include SignSettingsEmailRegistration

          include ::VerificationOperator

          AUTHENTICATION_MODE = :private

          before_action :authenticate_operator!
          # Object-level authorization (ActionPolicy): registering an email is a fresh-record action
          # for the authenticated operator, so gate by actor type. Each flow step builds/looks up the
          # email through current_operator.staff_emails (owner-scoped). Step-up/turnstile remain below.
          before_action :authorize_email_registration!, only: %i(new create edit update)
          step_up only: %i(new create edit update)

          def new
            @staff_email = OperatorEmail.new
            reset_registration_session!
          end

          def edit
            @staff_email = current_registration_email
            return if valid_registration_session?

            reset_registration_session!
            redirect_to(
              new_auth_org_settings_emails_registration_path,
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

            OtpAdapter.for(surface: :org, channel: :email).deliver(
              record: @staff_email,
              otp_code: otp_code,
              verification_token: nil,
              public_id: @staff_email.public_id,
            )

            session[registration_session_key] = @staff_email.public_id
            start_email_ceremony!(
              surface: "org",
              actor: current_operator,
              session_ref: current_session_public_id,
              candidate: @staff_email,
            )
            redirect_to(
              edit_auth_org_settings_emails_registration_path,
            )
          end

          def update
            @staff_email = current_registration_email
            return fail_registration_session unless valid_registration_session?
            return fail_turnstile unless cloudflare_turnstile_stealth_validation["success"]

            submitted_code = params.dig(:staff_email, :pass_code)
            return fail_code_required if submitted_code.blank?

            result = verify_otp_code(@staff_email, submitted_code)
            return fail_otp_invalid unless result[:success]

            complete_registration!
          end

          private

          def authorize_email_registration!
            authorize!(OperatorEmail, to: :create?)
          end

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
            reset_email_ceremony_session!
          end

          def fail_registration_session
            reset_registration_session!
            redirect_to(
              new_auth_org_settings_emails_registration_path,
            )
          end

          def fail_turnstile
            @staff_email.errors.add(:base, t("turnstile_error"))
            render(:edit, status: :unprocessable_content)
          end

          def fail_code_required
            @staff_email.errors.add(:pass_code, t("sign.org.registration.email.update.code_required"))
            render :edit, status: :unprocessable_content
          end

          def fail_otp_invalid
            increment_otp_attempts!(@staff_email)
            if @staff_email.locked?
              @staff_email.destroy!
              reset_registration_session!
              redirect_to(
                new_auth_org_settings_emails_registration_path,
              )
            else
              @staff_email.errors.add(:pass_code, t("sign.org.registration.email.update.invalid_code"))
              render :edit, status: :unprocessable_content
            end
          end

          def complete_registration!
            clear_otp(@staff_email)
            @staff_email.save! if @staff_email.changed?
            finish_email_ceremony!(
              surface: "org",
              actor: current_operator,
              session_ref: current_session_public_id,
              candidate: @staff_email,
            )
            reset_registration_session!
            redirect_to(
              bootstrap_return_path(
                auth_org_settings_emails_url(
                  ri: params[:ri],
                  host: ENV.fetch("PRIVATE_AUTH_STAFF_URL"),
                ),
              ),
              allow_other_host: cross_host_redirect_allowed?,
            )
          end

          def verification_required_action?
            true
          end

          def verification_scope
            "settings_email"
          end
        end
      end
    end
  end
end
