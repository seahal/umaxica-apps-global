# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Social
      # GET /social/(google|apple)/registration/new
      # Starts the social sign-up ceremony. The provider and the sign-up entry
      # marker arrive as route defaults; the shared ceremony start issues the
      # sign-up flow ticket when the entry is a sign-up.
      class RegistrationsController < AuthenticationsController
        AUTHENTICATION_MODE = :open

        declare_authentication_mode! :open, only: :new

        def new
          start_social_ceremony!
        end
      end
    end
  end
end
