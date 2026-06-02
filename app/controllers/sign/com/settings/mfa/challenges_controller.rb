# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Settings
      module Mfa
        class ChallengesController < Sign::Com::ApplicationController
          include ::Verification::Visitor

          AUTHENTICATION_MODE = :private

          before_action :authenticate_visitor!
          # Object-level authorization (ActionPolicy): the MFA level is an account-self attribute
          # on the visitor, so only the owner may view/update it. Reuses VisitorPolicy#show?/#update?
          # (owner-self), mirroring the birthdate page. Step-up/verification guards remain below.
          before_action :authorize_mfa_challenge!, only: %i(show update)

          def show
            @user = current_visitor
            @passkeys = current_visitor.visitor_passkeys.active.order(created_at: :desc)
            @secret_credentials =
              current_visitor.visitor_secret_credentials
                .where(visitor_secret_credential_status_id: VisitorSecretCredentialStatus::ACTIVE)
                .order(created_at: :desc)
          end

          def update
            mfa_level_id = requested_mfa_level_id
            visitor = Visitor.find(current_visitor.id)
            visitor.mfa_level_id = mfa_level_id
            visitor.mfa_level_enabled = mfa_level_id != VisitorMfaLevel::NOTHING
            visitor.save!

            redirect_to(
              sign_com_settings_mfa_challenge_path(ri: params[:ri]),
              notice: t("sign.app.settings.mfa.update.success"),
            )
          rescue ActiveRecord::RecordInvalid, ArgumentError
            show
            flash.now[:alert] = t("sign.app.settings.mfa.update.failure")
            render :show, status: :unprocessable_content
          end

          private

          def authorize_mfa_challenge!
            authorize!(current_visitor, to: :"#{action_name}?")
          end

          def verification_required_action?
            action_name == "update"
          end

          def verification_scope
            "settings_mfa"
          end

          def requested_mfa_level_id
            user_params = params.fetch(:user, {})
            mfa_level_id = Integer(user_params[:mfa_level_id].to_s, 10)
            return mfa_level_id if [VisitorMfaLevel::NOTHING, VisitorMfaLevel::FULL].include?(mfa_level_id)

            raise ArgumentError, "unsupported multi factor level"
          end
        end
      end
    end
  end
end
