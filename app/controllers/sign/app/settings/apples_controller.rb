# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class ApplesController < ::Sign::App::ApplicationController
        include ::VerificationClient

        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!

        # Object-level authorization (ActionPolicy): the Apple link-status page reads the client's
        # own account, so gate owner-self via ClientPolicy#show? (mirrors the birthdate page).
        def show
          authorize!(current_client, to: :show?)
        end
      end
    end
  end
end
