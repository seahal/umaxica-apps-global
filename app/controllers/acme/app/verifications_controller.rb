# typed: false
# frozen_string_literal: true

module Acme
  module App
    class VerificationsController < Acme::App::ApplicationController
      include AcmeStepUpIntent
      include AcmeStepUpCompletion

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def show
        authorize!(current_client, to: :show?)
        redirect_to_step_up_ceremony!(
          surface: "app",
          actor: current_client,
          token: current_session_token,
          allowed_scopes: StepUpScopeCatalog::APP,
          sign_url_builder: ->(**query) {
            sign_app_verification_url(
              query.merge(host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost")),
            )
          },
        )
      end

      def completion
        authorize!(current_client, to: :show?)
        complete_step_up_ceremony!(
          surface: "app",
          actor: current_client,
          token: current_session_token,
          fallback: acme_app_dashboard_path(ri: params[:ri]),
        )
      end

      private

      def actor_verification_path(**args)
        acme_app_verification_path(**args)
      end
    end
  end
end
