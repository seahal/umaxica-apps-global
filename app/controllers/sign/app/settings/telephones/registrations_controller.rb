# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      module Telephones
        class RegistrationsController < ::Sign::App::ApplicationController
          include CloudflareTurnstile

          include CommonRedirect
          include CommonOtp
          include SignTelephoneRegistrable
          include SignTelephoneCeremonyDelegation

          include ::VerificationClient

          AUTHENTICATION_MODE = :private

          before_action :authenticate_client!
          # Object-level authorization (ActionPolicy): registering a telephone is a fresh-record action
          # for the authenticated client, so gate by actor type. Each step builds/looks up the record
          # for current_client. Verification/turnstile guards remain on the flow.
          before_action :authorize_telephone_registration!, only: %i(new create edit update)

          def new
            @user_telephone = ClientTelephone.new
            reset_registration_session!
            accept_telephone_ceremony_grant!(surface: "app")
          end

          def edit
            @user_telephone = current_registration_telephone
            return if valid_registration_session?

            reset_registration_session!
            redirect_to(
              new_sign_app_settings_telephones_registration_path,
              notice: t("sign.app.registration.telephone.edit.session_expired"),
            )
          end

          def create
            user = current_client
            return head :unauthorized if user.blank?

            unless cloudflare_turnstile_stealth_validation["success"]
              @user_telephone = ClientTelephone.new
              @user_telephone.errors.add(:base, t("turnstile_error"))
              flash.now[:alert] = t("turnstile_error")
              render(:new, status: :unprocessable_content)
              return
            end

            tel_params = params.expect(user_telephone: [:raw_number, :number])
            number = tel_params[:raw_number] || tel_params[:number]

            unless initiate_telephone_verification(user, number, auto_accept_confirmations: true)
              render :new, status: :unprocessable_content
              return
            end

            session[registration_session_key] = @user_telephone.id
            start_telephone_ceremony!(
              surface: "app",
              actor: current_client,
              session_ref: current_session_public_id,
              candidate: @user_telephone,
            )
            redirect_to(
              edit_sign_app_settings_telephones_registration_path,
              notice: t("sign.app.registration.telephone.create.verification_code_sent"),
            )
          end

          def update
            @user_telephone = current_registration_telephone

            unless valid_registration_session?
              reset_registration_session!
              redirect_to(
                new_sign_app_settings_telephones_registration_path,
                notice: t("sign.app.registration.telephone.edit.session_expired"),
              )
              return
            end

            unless cloudflare_turnstile_stealth_validation["success"]
              @user_telephone.errors.add(:base, t("turnstile_error"))
              flash.now[:alert] = t("turnstile_error")
              render(:edit, status: :unprocessable_content)
              return
            end

            submitted_code = params.dig(:user_telephone, :pass_code)
            if submitted_code.blank?
              @user_telephone.errors.add(
                :pass_code,
                t("sign.app.registration.telephone.update.code_required"),
              )
              render :edit, status: :unprocessable_content
              return
            end

            status = complete_telephone_verification(@user_telephone.id, submitted_code)

            handle_registration_update_status(status)
          end

          private

          def authorize_telephone_registration!
            authorize!(ClientTelephone, to: :create?)
          end

          def handle_registration_update_status(status)
            case status
            when :success
              finish_telephone_ceremony!(
                surface: "app",
                actor: current_client,
                session_ref: current_session_public_id,
                candidate: @user_telephone,
              )
              reset_registration_session!
              redirect_to(
                sign_app_settings_telephones_url(
                  ri: params[:ri],
                  host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
                ),
                notice: t("sign.app.registration.telephone.update.success"),
                allow_other_host: cross_host_redirect_allowed?,
              )
            when :session_expired
              reset_registration_session!
              redirect_to(
                new_sign_app_settings_telephones_registration_path,
                notice: t("sign.app.registration.telephone.edit.session_expired"),
              )
            when :locked
              reset_registration_session!
              flash[:alert] = t("sign.app.registration.telephone.update.attempts_exceeded")
              redirect_to(new_sign_app_settings_telephones_registration_path)
            else
              render :edit, status: :unprocessable_content
            end
          end

          def current_registration_telephone
            ClientTelephone.find_by(id: session[registration_session_key])
          end

          def valid_registration_session?
            @user_telephone.present? &&
              @user_telephone.user_id == current_client.id &&
              !@user_telephone.otp_expired? &&
              @user_telephone.user_telephone_status_id == ClientTelephoneStatus::UNVERIFIED
          end

          def registration_session_key
            :settings_telephone_registration_id
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
