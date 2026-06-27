# typed: false
# frozen_string_literal: true

module Base
  module Org
    class VerificationsController < Base::Org::ApplicationController
      include BaseStepUpIntent
      include BaseStepUpCompletion
      include BaseStepUpCancellation

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def show
        authorize!(current_operator, to: :show?)
        redirect_to_step_up_ceremony!(
          surface: "org",
          actor: current_operator,
          token: current_session_token,
          allowed_scopes: StepUpScopeCatalog::ORG,
          sign_url_builder: ->(**query) {
            auth_org_verification_url(
              query.merge(host: ENV.fetch("SIGN_STAFF_URL", "id.org.localhost")),
            )
          },
        )
      end

      def completion
        authorize!(current_operator, to: :show?)
        complete_step_up_ceremony!(
          surface: "org",
          actor: current_operator,
          token: current_session_token,
          fallback: base_org_dashboard_path(ri: params[:ri]),
        )
      end

      def cancellation
        authorize!(current_operator, to: :show?)
        cancel_step_up_ceremony!(
          surface: "org",
          actor: current_operator,
          token: current_session_token,
          fallback: base_org_dashboard_path(ri: params[:ri]),
        )
      end

      private

      def actor_verification_path(**args)
        base_org_verification_path(**args)
      end
    end
  end
end
