# typed: false
# frozen_string_literal: true

module Base
  module Org
    module SignOuts
      class CompletionsController < Base::Org::SignOutsController
        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        after_action :sign_out_notice_cache_headers!, only: :show

        def show
          complete
        end
      end
    end
  end
end
