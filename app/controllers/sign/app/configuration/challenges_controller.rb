# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class ChallengesController < ApplicationController
        auth_required!

        include ::Verification::User

        before_action :authenticate_user!

        def show
          @user = current_user
          @passkeys = current_user.user_passkeys.active.order(created_at: :desc)
          @totps =
            current_user.user_one_time_passwords
              .where(user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE)
              .order(created_at: :desc)
          @secrets =
            current_user.user_secrets
              .where(user_identity_secret_status_id: UserSecretStatus::ACTIVE)
              .order(created_at: :desc)
        end

        def update
          multi_factor_id = requested_multi_factor_id
          current_user.multi_factor_id = multi_factor_id
          current_user.multi_factor_enabled = multi_factor_id != UserMultiFactor::NOTHING
          current_user.save!

          redirect_to(
            sign_app_configuration_challenge_path(ri: params[:ri]),
            notice: t("sign.app.configuration.mfa.update.success"),
          )
        rescue ActiveRecord::RecordInvalid, ArgumentError
          show
          flash.now[:alert] = t("sign.app.configuration.mfa.update.failure")
          render :show, status: :unprocessable_content
        end

        private

        def verification_required_action?
          %w(show update).include?(action_name)
        end

        def verification_scope
          "configuration_mfa"
        end

        def requested_multi_factor_id
          multi_factor_id = Integer(params.dig(:user, :multi_factor_id).to_s, 10)
          return multi_factor_id if [UserMultiFactor::NOTHING, UserMultiFactor::FULL].include?(multi_factor_id)

          raise ArgumentError, "unsupported multi factor level"
        end
      end
    end
  end
end
