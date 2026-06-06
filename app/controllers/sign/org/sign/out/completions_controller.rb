# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Sign
      module Out
        class CompletionsController < ::Sign::Org::ApplicationController
          include ::SignOutNotice

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          helper_method :sign_out_completed_description

          def show
            @sign_out_notice = consume_sign_out_notice
            render "acme/shared/sign_outs/show"
          end
        end
      end
    end
  end
end
