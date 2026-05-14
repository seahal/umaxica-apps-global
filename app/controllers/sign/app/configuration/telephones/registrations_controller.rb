# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      module Telephones
        class RegistrationsController < ::Sign::App::ApplicationController
          auth_required!

          include CloudflareTurnstile
          include Sign::TelephoneRegistrable
          include ::Verification::User

          before_action :authenticate_user!

          def new
            @user_telephone = UserTelephone.new
            reset_registration_session!
          end

          def edit
            @user_telephone = current_registration_telephone
            return if valid_registration_session?

            reset_registration_session!
            redirect_to(
              new_sign_app_configuration_telephones_registration_path,
              notice: t("sign.app.registration.telephone.edit.session_expired"),
            )
          end

          def create
            user = current_user
            return head :unauthorized if user.blank?

            unless cloudflare_turnstile_stealth_validation["success"]
              @user_telephone = UserTelephone.new
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
            redirect_to(
              edit_sign_app_configuration_telephones_registration_path,
              notice: t("sign.app.registration.telephone.create.verification_code_sent"),
            )
          end

          def update
            @user_telephone = current_registration_telephone

            unless valid_registration_session?
              reset_registration_session!
              redirect_to(
                new_sign_app_configuration_telephones_registration_path,
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

            status =
              complete_telephone_verification(@user_telephone.id, submitted_code) do |user_telephone|
                user_telephone.user = current_user
                user_telephone.save!
              end

            case status
            when :success
              record_telephone_registration_step_up!
              reset_registration_session!
              redirect_to(
                sign_app_configuration_telephones_path,
                notice: t("sign.app.registration.telephone.update.success"),
              )
            when :session_expired
              reset_registration_session!
              redirect_to(
                new_sign_app_configuration_telephones_registration_path,
                notice: t("sign.app.registration.telephone.edit.session_expired"),
              )
            when :locked
              reset_registration_session!
              flash[:alert] = t("sign.app.registration.telephone.update.attempts_exceeded")
              redirect_to(new_sign_app_configuration_telephones_registration_path)
            else
              render :edit, status: :unprocessable_content
            end
          end

          private

          def current_registration_telephone
            UserTelephone.find_by(id: session[registration_session_key])
          end

          def valid_registration_session?
            @user_telephone.present? &&
              @user_telephone.user_id == current_user.id &&
              !@user_telephone.otp_expired? &&
              @user_telephone.user_telephone_status_id == UserTelephoneStatus::UNVERIFIED
          end

          def registration_session_key
            :configuration_telephone_registration_id
          end

          def reset_registration_session!
            session.delete(registration_session_key)
          end

          def record_telephone_registration_step_up!
            current_session_token&.update!(
              last_step_up_at: Time.current,
              last_step_up_scope: verification_scope,
            )
            create_audit_event!(UserChronicleEvent::TELEPHONE_REGISTERED)
          end

          def create_audit_event!(event_id)
            ChronicleRecord.connected_to(role: :writing) do
              UserChronicleEvent.find_or_create_by!(id: event_id)
              UserChronicleLevel.find_or_create_by!(id: UserChronicleLevel::NOTHING)
            end

            UserChronicle.create!(
              actor_type: "User",
              actor_id: current_user.id,
              event_id: event_id,
              subject_id: current_user.id.to_s,
              subject_type: "User",
              occurred_at: Time.current,
            )
          end

          def verification_required_action?
            true
          end

          def verification_scope
            "configuration_telephone"
          end
        end
      end
    end
  end
end
