# typed: false
# frozen_string_literal: true

module Core
  module Org
    module SignOuts
      class CompletionsController < Core::Org::SignOutsController
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
