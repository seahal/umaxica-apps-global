# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class BirthdatesController < BaseController
        include VerificationClient

        before_action :authenticate_client!
        before_action :authorize_birthdate!, only: :show
        step_up only: :show
        def show; render "auth/app/settings/birthdates/show"; end

        private

        def authorize_birthdate! = authorize!(current_client, to: :show?)

        def verification_scope = "settings_birthdate"
      end
    end
  end
end
