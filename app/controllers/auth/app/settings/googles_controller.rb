# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Settings
      class GooglesController < ::Auth::App::ApplicationController
        include CloudflareTurnstile
        include SocialAuth
        include ::SignSocialAuthenticationEndpoint
        include ::VerificationClient

        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!
        before_action :authorize_google_settings!, only: %i(show edit create destroy)
        before_action :require_step_up_for_mutation!, only: %i(edit create destroy)
        before_action :authorize_social_unlink!, only: :destroy

        # Object-level authorization (ActionPolicy): the Google link-status page reads the client's
        # own account, so gate owner-self via ClientPolicy#show? (mirrors the birthdate page).
        def show
        end

        def edit
        end

        def create
          continue_social_authentication(provider: social_provider, intent: "link")
        end

        def destroy
          disconnect_social_authentication(provider: social_provider)
        end

        private

        def authorize_google_settings!
          authorize!(current_client, to: :show?)
        end

        def require_step_up_for_mutation!
          return render_unlink_blocked unless social_operation_allowed?

          scope = social_operation_scope
          return true if step_up_satisfied?(scope: scope)

          redirect_to(
            actor_verification_path(
              scope: scope,
              pt: encoded_relative_pt(edit_auth_app_settings_google_path(ri: params[:ri])),
              ri: params[:ri],
            ),
            status: :see_other,
          )
          false
        end

        def social_operation_scope
          social_provider_linked? ? verification_scope : SOCIAL_LINK_SCOPE
        end

        def social_operation_allowed?
          return false if action_name == "create" && social_provider_linked?
          return true unless social_operation_scope == verification_scope

          current_client.social_unlink_methods_remaining?(excluding_provider: social_provider)
        end

        def render_unlink_blocked
          render :edit, status: :unprocessable_content
          false
        end

        def social_provider_linked?
          action_name == "destroy" || current_client.active_social_provider?(social_provider)
        end

        def social_provider
          "google"
        end
      end
    end
  end
end
