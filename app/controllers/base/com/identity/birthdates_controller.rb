# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class BirthdatesController < ::Base::Com::ApplicationController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_visitor!
        # Object-level authorization (ActionPolicy): only the owner may view their own birthdate.
        # Step-up freshness is still enforced separately below.
        before_action :authorize_birthdate!, only: :show
        step_up only: :show

        def show
        end

        private

        def authorize_birthdate!
          authorize!(current_visitor, to: :show?)
        end

        def verification_scope
          "settings_birthdate"
        end
      end
    end
  end
end
