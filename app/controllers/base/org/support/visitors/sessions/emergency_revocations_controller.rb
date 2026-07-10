# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Support
      module Visitors
        module Sessions
          class EmergencyRevocationsController < Base::Org::Support::Visitors::SessionsController
            AUTHENTICATION_MODE = :private
            declare_authentication_mode! :private

            def destroy
              emergency_revoke
            end
          end
        end
      end
    end
  end
end
