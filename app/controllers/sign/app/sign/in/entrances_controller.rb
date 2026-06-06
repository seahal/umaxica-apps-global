# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Sign
      module In
        class EntrancesController < ::Sign::App::SignInsController
          AUTHENTICATION_MODE = :guest
          declare_authentication_mode! :guest

          def show
            render "sign/app/sign_ins/new"
          end
        end
      end
    end
  end
end
