# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class VerificationsController < Acme::Org::ApplicationController
      include Acme::StepUpIntent
      include Acme::StepUpCompletion

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def show
        authorize!(current_operator, to: :show?)
        redirect_to_step_up_ceremony!(
          surface: "org",
          actor: current_operator,
          token: current_session_token,
          allowed_scopes: StepUp::ScopeCatalog::ORG,
          sign_url_builder: ->(**query) {
            sign_org_verification_url(
              query.merge(host: ENV.fetch("ID_STAFF_URL", "id.org.localhost")),
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
          fallback: acme_org_settings_path(ri: params[:ri]),
        )
      end

      private

      def actor_verification_path(**args)
        acme_org_verification_path(**args)
      end
    end
  end
end
