# typed: false
# frozen_string_literal: true

module Side
  module Org
    module SignOuts
      class CompletionsController < Side::Org::SignOutsController
        AUTHENTICATION_MODE = :open

        after_action :sign_out_notice_cache_headers!, only: :show

        def show
          complete
        end
      end
    end
  end
end
