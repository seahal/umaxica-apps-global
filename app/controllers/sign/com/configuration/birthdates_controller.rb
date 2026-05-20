# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Configuration
      class BirthdatesController < PrivateController
        before_action :authenticate_visitor!
        before_action :require_birthdate_step_up!, only: :show

        def show
        end

        private

        def require_birthdate_step_up!
          return false if require_step_up!(scope: verification_scope) == false
          return true if birthdate_step_up_satisfied?

          redirect_to(
            actor_verification_path(
              scope: verification_scope,
              rt: encoded_relative_return_to(request.fullpath),
              ri: params[:ri],
            ),
          )
          false
        end

        def birthdate_step_up_satisfied?
          token = current_session_token
          return false unless token&.currently_usable?

          token.last_step_up_at.present? &&
            token.last_step_up_at > ::Verification::Base::STEP_UP_TTL.ago &&
            token.last_step_up_scope == verification_scope
        end

        def verification_scope
          "configuration_birthdate"
        end
      end
    end
  end
end
