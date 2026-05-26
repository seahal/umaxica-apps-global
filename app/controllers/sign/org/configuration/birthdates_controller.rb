# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class BirthdatesController < PrivateController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
        before_action :require_birthdate_step_up!, only: :show

        def show
        end

        private

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
