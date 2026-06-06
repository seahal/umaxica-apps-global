# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Sign
      module Up
        class EntrancesController < ::Sign::App::SignUpsController
          AUTHENTICATION_MODE = :guest
          declare_authentication_mode! :guest

          def show
            render "sign/app/sign_ups/new"
          end
        end
      end
    end
  end
end
