# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      class StandingsController < ::Base::Org::ApplicationController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_operator!

        def show
          authorize!(current_operator, to: :show?)
          @standing = AccountStandingResolver.call(
            enforcement_case_class: OrgEnforcementCase,
            principal_public_id: current_operator.public_id,
          )
          render "base/shared/identity/standings/show"
        end
      end
    end
  end
end
