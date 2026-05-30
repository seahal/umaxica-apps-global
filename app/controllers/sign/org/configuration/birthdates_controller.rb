# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class BirthdatesController < Sign::Org::ApplicationController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
        # Object-level authorization (ActionPolicy): only the owner may view their own birthdate.
        # Step-up freshness is still enforced separately below.
        before_action :authorize_birthdate!, only: :show
        before_action :require_birthdate_step_up!, only: :show

        def show
        end

        private

        def authorize_birthdate!
          authorize!(current_operator, to: :show?)
        end

        def require_birthdate_step_up!
          require_step_up!(scope: verification_scope)
        end

        def verification_scope
          "configuration_birthdate"
        end
      end
    end
  end
end
