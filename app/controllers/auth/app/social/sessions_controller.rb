# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Social
      # GET /social/(google|apple)/session/new
      # Starts the social sign-in ceremony. The provider arrives as a route
      # default; an explicit `intent` param may upgrade the ceremony to
      # "link" or "step_up" when arriving from settings.
      class SessionsController < AuthenticationsController
        AUTHENTICATION_MODE = :open

        # Login intent doesn't require auth; link/step-up intents are checked
        # in require_social_link_step_up! and prepare_social_auth_intent!.
        declare_authentication_mode! :open, only: :new
        before_action :require_social_link_step_up!, only: :new

        def new
          start_social_ceremony!
        end
      end
    end
  end
end
