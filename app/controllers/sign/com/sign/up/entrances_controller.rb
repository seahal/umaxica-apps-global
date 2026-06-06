# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Sign
      module Up
        class EntrancesController < ::Sign::Com::SignUpsController
          AUTHENTICATION_MODE = :guest
          declare_authentication_mode! :guest

          def show
            render "sign/com/sign_ups/new"
          end
        end
      end
    end
  end
end
