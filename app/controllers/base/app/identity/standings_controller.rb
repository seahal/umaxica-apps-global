# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class StandingsController < BaseController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!

        def show
          authorize!(current_client, to: :show?)
          @standing = AccountStandingResolver.call(
            enforcement_case_class: AppEnforcementCase,
            principal_public_id: current_client.public_id,
          )
          render "base/shared/identity/standings/show"
        end
      end
    end
  end
end
