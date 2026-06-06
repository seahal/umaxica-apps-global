# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      module Emails
        class RegistrationsController < ::Sign::App::ApplicationController
          include ::CloudflareTurnstile
          include CommonRedirect
          include CommonOtp
          include SignEmailRegistrable
          include SignEmailRegistrationFlow
          include SignEmailCeremonyDelegation

          include ::VerificationClient

          AUTHENTICATION_MODE = :private
          before_action :authenticate_client!
          before_action :preserve_email_registration_redirect_parameter, only: %i(new create edit update resend)
          # Object-level authorization (ActionPolicy): registering an email is a fresh-record action
          # for the authenticated client, so gate by actor type. Each flow step builds/looks up the
          # email through current_client.client_emails (owner-scoped). Step-up/turnstile remain below.
          before_action :authorize_email_registration!, only: %i(new create edit update)
          step_up only: %i(new create edit update), bootstrap: true
          def new = super

          def edit = super

          def create = super

          def update = super

          def resend = super

          private

          def authorize_email_registration!
            authorize!(ClientEmail, to: :create?)
          end

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
            edit_sign_app_settings_emails_registration_path(params)
          end

          def new_email_registration_path(params = {})
            new_sign_app_settings_emails_registration_path(params)
          end

          def after_email_registration_verified_path
            email_registration_return_path(
              acme_app_settings_emails_url(
                ri: params[:ri],
                host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
              ),
            )
          end

          def verification_required_action?
            step_up_bootstrap_active?
          end

          def verification_scope
            "settings_email"
          end

          def pending_email_status_id
            ClientEmailStatus::UNVERIFIED
          end

          def verified_email_status_id
            ClientEmailStatus::VERIFIED
          end

          def on_email_registration_verified!(*)
            nil
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
