# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      module Emails
        class RegistrationsController < ::Sign::App::PrivateController
          AUTHENTICATION_MODE = :private

          include Sign::EmailRegistrationFlow
          include ::Verification::Client

          before_action :authenticate_client!
          before_action only: %i(new create edit update) do
            require_step_up_unless_bootstrap!(scope: verification_scope)
          end

          private

          def ensure_turnstile!(email_address, confirm_policy)
            turnstile_result = cloudflare_turnstile_stealth_validation
            return true if turnstile_result["success"]

            @user_email = ClientEmail.new(raw_address: email_address, confirm_policy: confirm_policy)
            @user_email.errors.add(:base, t("sign.app.registration.email.create.turnstile_validation_failed"))
            false
          end

          def email_registration_target_user
            current_client
          end

          def after_email_registration_started_path(params = {})
            edit_sign_app_configuration_emails_registration_path(params)
          end

          def new_email_registration_path(params = {})
            new_sign_app_configuration_emails_registration_path(params)
          end

          def after_email_registration_verified_path
            email_registration_return_path(sign_app_configuration_emails_path(ri: params[:ri]))
          end

          def verification_required_action?
            step_up_bootstrap_active?
          end

          def verification_scope
            "configuration_email"
          end

          def pending_email_status_id
            ClientEmailStatus::UNVERIFIED
          end

          def verified_email_status_id
            ClientEmailStatus::VERIFIED
          end

          def on_email_registration_verified!(*)
            current_session_token&.update!(
              last_step_up_at: Time.current,
              last_step_up_scope: verification_scope,
            )
            create_audit_event!(ClientChronicleEvent::EMAIL_REGISTERED)
          end

          def create_audit_event!(event_id)
            ChronicleRecord.connected_to(role: :writing) do
              ClientChronicleEvent.find_or_create_by!(id: event_id)
              ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
            end

            ClientChronicle.create!(
              actor_type: "Client",
              actor_id: current_client.id,
              event_id: event_id,
              subject_id: current_client.id.to_s,
              subject_type: "Client",
              occurred_at: Time.current,
            )
          end

          def cleanup_pending_signup!
            nil
          end

          def remove_existing_unverified_emails!
            nil
          end
        end
      end
    end
  end
end
