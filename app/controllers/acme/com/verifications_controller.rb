# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class VerificationsController < Acme::Com::ApplicationController
      include AcmeStepUpIntent
      include AcmeStepUpCompletion

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def show
        authorize!(current_visitor, to: :show?)
        redirect_to_step_up_ceremony!(
          surface: "com",
          actor: current_visitor,
          token: current_session_token,
          allowed_scopes: StepUpScopeCatalog::COM,
          sign_url_builder: ->(**query) {
            sign_com_verification_url(
              query.merge(host: ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")),
            )
          },
        )
      end

      def completion
        authorize!(current_visitor, to: :show?)
        complete_step_up_ceremony!(
          surface: "com",
          actor: current_visitor,
          token: current_session_token,
          fallback: acme_com_settings_path(ri: params[:ri]),
        )
      end

      private

      def actor_verification_path(**args)
        acme_com_verification_path(**args)
      end
    end
  end
end
