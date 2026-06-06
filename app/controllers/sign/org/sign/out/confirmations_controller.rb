# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Sign
      module Out
        class ConfirmationsController < ::Sign::Org::ApplicationController
          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          before_action :authenticate_operator!

          def show
            render "acme/shared/sign_outs/edit"
          end
        end
      end
    end
  end
end
