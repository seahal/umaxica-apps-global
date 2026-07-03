# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Mfa
        class ChallengesController < BaseController
          include VerificationClient

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_client!
          before_action :authorize_mfa_challenge!, only: %i(show update)
          def show
            @user = current_client
            @passkeys = current_client.client_passkeys.active.order(created_at: :desc)
            @totps = current_client.client_totp_credentials
              .where(user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
              .order(created_at: :desc)
            @secret_credentials = current_client.client_secret_credentials
              .where(user_identity_secret_status_id: ClientSecretCredentialStatus::ACTIVE)
              .order(created_at: :desc)
            render "base/app/identity/mfa/challenges/show"
          end

          def update
            previous_mfa_level_id = current_client.mfa_level_id
            mfa_level_id = requested_mfa_level_id
            current_client.update!(mfa_level_id: mfa_level_id, mfa_level_enabled: mfa_level_id != ClientMfaLevel::NOTHING)
            CredentialSecurityTransition.call(
              actor: current_client,
              current_session: current_session,
              reason: (mfa_level_id == ClientMfaLevel::NOTHING) ? :mfa_disabled : :mfa_level_changed,
              affected_surface: "app",
              request: request,
            ) if previous_mfa_level_id != mfa_level_id
            redirect_to(
              base_app_identity_mfa_challenge_path(ri: params[:ri]),
            )
          rescue ActiveRecord::RecordInvalid, ArgumentError
            show
            current_client.errors.add(:base, t("sign.app.settings.mfa.update.failure"))
            render "base/app/identity/mfa/challenges/show", status: :unprocessable_content
          end

          private

          def authorize_mfa_challenge! = authorize!(current_client, to: :"#{action_name}?")

          def verification_required_action? = %w(show update).include?(action_name)

          def verification_scope = "settings_mfa"

          def requested_mfa_level_id
            mfa_level_id = Integer(params.dig(:user, :mfa_level_id).to_s, 10)
            allowed = [
              ClientMfaLevel::NOTHING,
              ClientMfaLevel::WEAK,
              ClientMfaLevel::MEDIUM,
              ClientMfaLevel::FULL,
            ]
            return mfa_level_id if allowed.include?(mfa_level_id)

            raise ArgumentError, "unsupported multi factor level"
          end
        end
      end
    end
  end
end
