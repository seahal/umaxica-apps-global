# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class GooglesController < ::Sign::App::ApplicationController
        include CloudflareTurnstile
        include SocialAuth
        include ::SignSocialAuthenticationEndpoint
        include ::VerificationClient

        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!
        before_action :authorize_google_settings!, only: %i(show edit update destroy)
        before_action :require_step_up_for_mutation!, only: %i(edit update destroy)
        before_action :authorize_social_unlink!, only: :destroy

        # Object-level authorization (ActionPolicy): the Google link-status page reads the client's
        # own account, so gate owner-self via ClientPolicy#show? (mirrors the birthdate page).
        def show
        end

        def edit
        end

        def update
          continue_social_authentication(provider: social_provider)
        end

        def destroy
          disconnect_social_authentication(provider: social_provider)
        end

        private

        def authorize_google_settings!
          authorize!(current_client, to: :show?)
        end

        def require_step_up_for_mutation!
          return true if step_up_satisfied?(scope: SOCIAL_LINK_SCOPE)

          redirect_to(
            actor_verification_path(
              scope: SOCIAL_LINK_SCOPE,
              pt: encoded_relative_pt(edit_sign_app_settings_google_path(ri: params[:ri])),
              ri: params[:ri],
            ),
            status: :see_other,
          )
          false
        end

        def social_provider
          "google"
        end
      end
    end
  end
end
