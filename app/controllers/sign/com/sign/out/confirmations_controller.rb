# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Sign
      module Out
        class ConfirmationsController < ::Sign::Com::ApplicationController
          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          before_action :authenticate_visitor!

          def show
            render "acme/shared/sign_outs/edit"
          end
        end
      end
    end
  end
end
