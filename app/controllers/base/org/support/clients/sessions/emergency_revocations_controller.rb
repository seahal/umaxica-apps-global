# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Support
      module Clients
        module Sessions
          class EmergencyRevocationsController < Base::Org::Support::Clients::SessionsController
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
