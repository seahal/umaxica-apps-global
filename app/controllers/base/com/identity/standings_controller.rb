# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class StandingsController < ::Base::Com::ApplicationController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_visitor!

        def show
          authorize!(current_visitor, to: :show?)
          @standing = AccountStandingResolver.call(
            enforcement_case_class: ComEnforcementCase,
            principal_public_id: current_visitor.public_id,
          )
          render "base/shared/identity/standings/show"
        end
      end
    end
  end
end
