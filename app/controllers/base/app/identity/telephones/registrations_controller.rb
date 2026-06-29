# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Telephones
        class RegistrationsController < BaseController
          include CloudflareTurnstile
          include CommonRedirect
          include CommonOtp
          include SignTelephoneRegistrable
          include SignSettingsTelephoneRegistration
          include VerificationClient

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_client!
          before_action :authorize_telephone_registration!, only: %i(new create edit update)

          def new
            @user_telephone = ClientTelephone.new
            reset_registration_session!
            render "auth/app/settings/telephones/registrations/new"
          end

          def edit
            @user_telephone = current_registration_telephone
            unless valid_registration_session?
              reset_registration_session!
              return redirect_to(
                new_base_app_identity_telephones_registration_path,
                notice: t("sign.app.registration.telephone.edit.session_expired"),
              )
            end
            render "auth/app/settings/telephones/registrations/edit"
          end

          def create
            unless cloudflare_turnstile_stealth_validation["success"]
              @user_telephone = ClientTelephone.new
              @user_telephone.errors.add(:base, t("turnstile_error"))
              return render(:new, status: :unprocessable_content)
            end
            tel_params = params.expect(user_telephone: [:raw_number, :number])
            number = tel_params[:raw_number] || tel_params[:number]
            return render(:new, status: :unprocessable_content) unless initiate_telephone_verification(
              current_client,
              number, auto_accept_confirmations: true,
            )

            session[registration_session_key] = @user_telephone.id
            start_telephone_ceremony!(
              surface: "app", actor: current_client, session_ref: current_session_public_id,
              candidate: @user_telephone,
            )
            redirect_to(
              edit_base_app_identity_telephones_registration_path,
              notice: t("sign.app.registration.telephone.create.verification_code_sent"),
            )
          end

          def update
            @user_telephone = current_registration_telephone
            unless valid_registration_session?
              reset_registration_session!
              return redirect_to(
                new_base_app_identity_telephones_registration_path,
                notice: t("sign.app.registration.telephone.edit.session_expired"),
              )
            end
            unless cloudflare_turnstile_stealth_validation["success"]
              @user_telephone.errors.add(:base, t("turnstile_error"))
              return render(:edit, status: :unprocessable_content)
            end
            status = complete_telephone_verification(@user_telephone.id, params.dig(:user_telephone, :pass_code))
            handle_registration_update_status(status)
          end

          private

          def authorize_telephone_registration! = authorize!(ClientTelephone, to: :create?)

          def handle_registration_update_status(status)
            case status
            when :success
              finish_telephone_ceremony!(
                surface: "app", actor: current_client, session_ref: current_session_public_id,
                candidate: @user_telephone,
              )
              reset_registration_session!
              redirect_to(
                base_app_identity_telephones_url(
                  ri: params[:ri],
                  host: preferred_base_service_host,
                ), notice: t("sign.app.registration.telephone.update.success"), status: :see_other,
              )
            when :session_expired
              reset_registration_session!
              redirect_to(
                new_base_app_identity_telephones_registration_path,
                notice: t("sign.app.registration.telephone.edit.session_expired"),
              )
            else
              render :edit, status: :unprocessable_content
            end
          end

          def preferred_base_service_host
            ENV.fetch("PUBLIC_BASE_SERVICE_URL")
          end

          def current_registration_telephone = ClientTelephone.find_by(id: session[registration_session_key])

          def valid_registration_session?
            @user_telephone.present? && @user_telephone.user_id == current_client.id &&
              !@user_telephone.otp_expired? &&
              @user_telephone.user_telephone_status_id == ClientTelephoneStatus::UNVERIFIED
          end

          def registration_session_key = :settings_telephone_registration_id

          def reset_registration_session!
            (session.delete(registration_session_key)
             reset_telephone_ceremony_session!)
          end

          def verification_required_action? = true

          def verification_scope = "settings_telephone"
        end
      end
    end
  end
end
