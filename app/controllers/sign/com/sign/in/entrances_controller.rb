# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Sign
      module In
        class EntrancesController < ::Sign::Com::SignInsController
          AUTHENTICATION_MODE = :guest
          declare_authentication_mode! :guest

          def show
            render "sign/com/sign_ins/new"
          end
        end
      end
    end
  end
end
