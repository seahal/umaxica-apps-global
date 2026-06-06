# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Sign
      module In
        class EntrancesController < ::Sign::Org::SignInsController
          AUTHENTICATION_MODE = :guest
          declare_authentication_mode! :guest

          def show
            render "sign/org/sign_ins/new"
          end
        end
      end
    end
  end
end
