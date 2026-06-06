# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      module Mfa
        class ChallengesController < Sign::App::ApplicationController
          include ::VerificationClient

          AUTHENTICATION_MODE = :private

          before_action :authenticate_client!
          # Object-level authorization (ActionPolicy): the MFA level is an account-self attribute
          # on the client, so only the owner may view/update it. Reuses ClientPolicy#show?/#update?
          # (owner-self), mirroring the birthdate page. Step-up/verification guards remain below.
          before_action :authorize_mfa_challenge!, only: %i(show update)

          def show
            @user = current_client
            @passkeys = current_client.client_passkeys.active.order(created_at: :desc)
            @totps =
              current_client.client_totp_credentials
                .where(user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
                .order(created_at: :desc)
            @secret_credentials =
              current_client.client_secret_credentials
                .where(user_identity_secret_status_id: ClientSecretCredentialStatus::ACTIVE)
                .order(created_at: :desc)
          end

          def update
            mfa_level_id = requested_mfa_level_id
            user = Client.find(current_client.id)
            user.mfa_level_id = mfa_level_id
            user.mfa_level_enabled = mfa_level_id != ClientMfaLevel::NOTHING
            user.save!

            redirect_to(
              sign_app_settings_mfa_challenge_path(ri: params[:ri]),
              notice: t("sign.app.settings.mfa.update.success"),
            )
          rescue ActiveRecord::RecordInvalid, ArgumentError
            show
            flash.now[:alert] = t("sign.app.settings.mfa.update.failure")
            render :show, status: :unprocessable_content
          end

          private

          def authorize_mfa_challenge!
            authorize!(current_client, to: :"#{action_name}?")
          end

          def verification_required_action?
            %w(show update).include?(action_name)
          end

          def verification_scope
            "settings_mfa"
          end

          def requested_mfa_level_id
            mfa_level_id = Integer(params.dig(:user, :mfa_level_id).to_s, 10)
            return mfa_level_id if [ClientMfaLevel::NOTHING, ClientMfaLevel::FULL].include?(mfa_level_id)

            raise ArgumentError, "unsupported multi factor level"
          end
        end
      end
    end
  end
end
