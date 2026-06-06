# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Settings
      module Telephones
        class RegistrationsController < ::Sign::Org::ApplicationController
          include CloudflareTurnstile

          include SignOperatorTelephoneRegistrable
          include SignTelephoneCeremonyDelegation

          include ::VerificationOperator

          AUTHENTICATION_MODE = :private

          before_action :authenticate_operator!
          # Object-level authorization (ActionPolicy): registering a telephone is a fresh-record action
          # for the authenticated operator, so gate by actor type. Each step builds/looks up the record
          # for current_operator. Verification/turnstile guards remain on the flow.
          before_action :authorize_telephone_registration!, only: %i(new create edit update)

          def new
            @staff_telephone = OperatorTelephone.new
            reset_registration_session!
            return if accept_telephone_ceremony_grant!(surface: "org")

            redirect_to(
              acme_org_settings_telephones_url(
                ri: params[:ri],
                host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
              ),
              notice: t("sign.org.registration.telephone.edit.session_expired"),
              allow_other_host: cross_host_redirect_allowed?,
            )
          end

          def edit
            @staff_telephone = current_registration_telephone
            return if valid_registration_session?

            reset_registration_session!
            redirect_to(
              new_sign_org_settings_telephones_registration_path,
              notice: t("sign.org.registration.telephone.edit.session_expired"),
            )
          end

          def create
            unless cloudflare_turnstile_stealth_validation["success"]
              @staff_telephone = OperatorTelephone.new
              @staff_telephone.errors.add(:base, t("turnstile_error"))
              flash.now[:alert] = t("turnstile_error")
              render(:new, status: :unprocessable_content)
              return
            end

            tel_params = params(staff_telephone: [:raw_number, :number])
            number = tel_params[:raw_number] || tel_params[:number]

            unless initiate_staff_telephone_verification(current_operator, number)
              render :new, status: :unprocessable_content
              return
            end

            session[registration_session_key] = @staff_telephone.id
            start_telephone_ceremony!(
              surface: "org",
              actor: current_operator,
              session_ref: current_session_public_id,
              candidate: @staff_telephone,
            )
            redirect_to(
              edit_sign_org_settings_telephones_registration_path,
              notice: t("sign.org.registration.telephone.create.verification_code_sent"),
            )
          end

          def update
            @staff_telephone = current_registration_telephone
            unless valid_registration_session?
              reset_registration_session!
              redirect_to(
                new_sign_org_settings_telephones_registration_path,
                notice: t("sign.org.registration.telephone.edit.session_expired"),
              )
              return
            end

            unless cloudflare_turnstile_stealth_validation["success"]
              @staff_telephone.errors.add(:base, t("turnstile_error"))
              flash.now[:alert] = t("turnstile_error")
              render(:edit, status: :unprocessable_content)
              return
            end

            submitted_code = params.dig(:staff_telephone, :pass_code)
            if submitted_code.blank?
              @staff_telephone.errors.add(:pass_code, t("sign.org.registration.telephone.update.code_required"))
              render :edit, status: :unprocessable_content
              return
            end

            result = complete_staff_telephone_verification(@staff_telephone.id, submitted_code)

            handle_registration_update_result(result)
          end

          private

          def authorize_telephone_registration!
            authorize!(OperatorTelephone, to: :create?)
          end

          def handle_registration_update_result(result)
            case result
            when :success
              finish_telephone_ceremony!(
                surface: "org",
                actor: current_operator,
                session_ref: current_session_public_id,
                candidate: @staff_telephone,
              )
              reset_registration_session!
              redirect_to(
                acme_org_settings_telephones_url(
                  ri: params[:ri],
                  host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
                ),
                notice: t("sign.org.registration.telephone.update.success"),
                allow_other_host: cross_host_redirect_allowed?,
              )
            when :session_expired
              reset_registration_session!
              redirect_to(
                new_sign_org_settings_telephones_registration_path,
                notice: t("sign.org.registration.telephone.edit.session_expired"),
              )
            when :locked
              reset_registration_session!
              redirect_to(
                new_sign_org_settings_telephones_registration_path,
                alert: t("sign.org.registration.telephone.update.attempts_exceeded"),
              )
            else
              render :edit, status: :unprocessable_content
            end
          end

          def current_registration_telephone
            current_operator.staff_telephones.find_by(id: session[registration_session_key])
          end

          def valid_registration_session?
            @staff_telephone.present? &&
              !@staff_telephone.otp_expired? &&
              @staff_telephone.staff_telephone_status_id == OperatorTelephoneStatus::UNVERIFIED
          end

          def registration_session_key
            :staff_telephone_registration_id
          end

          def reset_registration_session!
            session.delete(registration_session_key)
            reset_telephone_ceremony_session!
          end

          def verification_required_action?
            true
          end

          def verification_scope
            "settings_telephone"
          end
        end
      end
    end
  end
end
