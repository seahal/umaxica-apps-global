# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Sign
      module Up
        class EntrancesController < ::Sign::Org::SignUpsController
          AUTHENTICATION_MODE = :guest
          declare_authentication_mode! :guest

          def show
            render "sign/org/sign_ups/new"
          end
        end
      end
    end
  end
end
