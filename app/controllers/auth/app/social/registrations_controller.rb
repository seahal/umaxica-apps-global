# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Social
      # POST /social/(google|apple)/registration
      #
      # Starts the social sign-up ceremony. The provider and the sign-up entry
      # marker arrive as route defaults; the shared ceremony entry issues the
      # sign-up flow ticket when the entry is a sign-up.
      class RegistrationsController < ::Auth::App::ApplicationController
        include AppSocialCeremonyEntry

        AUTHENTICATION_MODE = :open

        declare_authentication_mode! :open, only: :create
        before_action :require_social_link_step_up!, only: :create

        def create
          handoff_social_ceremony!
        end
      end
    end
  end
end
