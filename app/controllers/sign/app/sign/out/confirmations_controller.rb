# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Sign
      module Out
        class ConfirmationsController < ::Sign::App::ApplicationController
          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          prepend_before_action :authenticate_client!

          def show
            render "acme/shared/sign_outs/edit"
          end
        end
      end
    end
  end
end
