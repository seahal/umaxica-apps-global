# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Settings
      module Mfa
        class ChallengesController < ::Auth::Org::ApplicationController
          include ::VerificationOperator

          AUTHENTICATION_MODE = :private

          before_action :authenticate_operator!
          # Object-level authorization (ActionPolicy): the MFA level is an account-self attribute
          # on the operator, so only the owner may view/update it. Reuses OperatorPolicy#show?/#update?
          # (owner-self), mirroring the birthdate page. Step-up/verification guards remain below.
          before_action :authorize_mfa_challenge!, only: %i(show update)

          def show
            @user = current_operator
            @passkeys = current_operator.staff_passkeys.active.order(created_at: :desc)
            @secret_credentials =
              current_operator.staff_secret_credentials
                .where(staff_identity_secret_status_id: OperatorSecretCredentialStatus::ACTIVE)
                .order(created_at: :desc)
          end

          def update
            mfa_level_id = requested_mfa_level_id
            current_operator.mfa_level_id = mfa_level_id
            current_operator.mfa_level_enabled = mfa_level_id != OperatorMfaLevel::NOTHING
            current_operator.save!

            redirect_to(
              sign_org_settings_mfa_challenge_path(ri: params[:ri]),
              notice: t("sign.app.settings.mfa.update.success"),
            )
          rescue ActiveRecord::RecordInvalid, ArgumentError
            show
            current_operator.errors.add(:base, t("sign.app.settings.mfa.update.failure"))
            render :show, status: :unprocessable_content
          end

          private

          def authorize_mfa_challenge!
            authorize!(current_operator, to: :"#{action_name}?")
          end

          def verification_required_action?
            action_name == "update"
          end

          def verification_scope
            "settings_mfa"
          end

          def requested_mfa_level_id
            mfa_level_id = Integer(params.dig(:user, :mfa_level_id).to_s, 10)
            return mfa_level_id if [OperatorMfaLevel::NOTHING, OperatorMfaLevel::FULL].include?(mfa_level_id)

            raise ArgumentError, "unsupported multi factor level"
          end
        end
      end
    end
  end
end
