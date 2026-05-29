# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Configuration
      module Mfa
        class ChallengesController < Sign::Com::ApplicationController
          include ::Verification::Visitor

          AUTHENTICATION_MODE = :private

          before_action :authenticate_visitor!

          def show
            @user = current_visitor
            @passkeys = current_visitor.visitor_passkeys.active.order(created_at: :desc)
            @secrets =
              current_visitor.visitor_secrets
                .where(visitor_secret_status_id: VisitorSecretStatus::ACTIVE)
                .order(created_at: :desc)
          end

          def update
            multi_factor_id = requested_multi_factor_id
            visitor = Visitor.find(current_visitor.id)
            visitor.multi_factor_id = multi_factor_id
            visitor.multi_factor_enabled = multi_factor_id != VisitorMultiFactor::NOTHING
            visitor.save!

            redirect_to(
              sign_com_configuration_mfa_challenge_path(ri: params[:ri]),
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
            user_params = params.fetch(:user, {})
            multi_factor_id = Integer(user_params[:multi_factor_id].to_s, 10)
            return multi_factor_id if [VisitorMultiFactor::NOTHING, VisitorMultiFactor::FULL].include?(multi_factor_id)

            raise ArgumentError, "unsupported multi factor level"
          end
        end
      end
    end
  end
end
