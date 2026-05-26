# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      module Mfa
        class ChallengesController < PrivateController
          include ::Verification::Operator

          AUTHENTICATION_MODE = :private

          before_action :authenticate_operator!

          def show
            @user = current_operator
            @passkeys = current_operator.staff_passkeys.active.order(created_at: :desc)
            @secrets =
              current_operator.staff_secrets
                .where(staff_identity_secret_status_id: OperatorSecretStatus::ACTIVE)
                .order(created_at: :desc)
          end

          def update
            multi_factor_id = requested_multi_factor_id
            current_operator.multi_factor_id = multi_factor_id
            current_operator.multi_factor_enabled = multi_factor_id != OperatorMultiFactor::NOTHING
            current_operator.save!

            redirect_to(
              sign_org_configuration_mfa_challenge_path(ri: params[:ri]),
              notice: t("sign.app.configuration.mfa.update.success"),
            )
          rescue ActiveRecord::RecordInvalid, ArgumentError
            show
            flash.now[:alert] = t("sign.app.configuration.mfa.update.failure")
            render :show, status: :unprocessable_content
          end

          private

          def verification_required_action?
            action_name == "update"
          end

          def verification_scope
            "configuration_mfa"
          end

          def requested_multi_factor_id
            multi_factor_id = Integer(params.dig(:user, :multi_factor_id).to_s, 10)
            return multi_factor_id if [OperatorMultiFactor::NOTHING, OperatorMultiFactor::FULL].include?(multi_factor_id)

            raise ArgumentError, "unsupported multi factor level"
          end
        end
      end
    end
  end
end
