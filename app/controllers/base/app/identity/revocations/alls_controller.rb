# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Revocations
        class AllsController < BaseController
          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_client!
          step_up only: %i(create destroy)

          # Self-service "sign out everywhere" goes through the same
          # `logout_all_sessions_for!` chokepoint as com/org so the batch
          # bumps `session_version`, writes the logout audit record, clears
          # auth cookies, and resets the Rails session. A bare token revoke
          # loop skips all four.
          def create
            logout_all_sessions_for!(resource: current_client, reason: "settings.session.revoke_all")
            redirect_to(base_app_sign_out_path(ri: params[:ri]), status: :see_other)
          end
          alias_method :destroy, :create

          private

          def verification_scope = "session_revoke_all"
        end
      end
    end
  end
end
