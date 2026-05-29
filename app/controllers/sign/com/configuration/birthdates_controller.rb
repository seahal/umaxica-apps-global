# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Configuration
      class BirthdatesController < Sign::Com::ApplicationController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_visitor!
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
