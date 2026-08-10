# typed: false
# frozen_string_literal: true

module Side
  module Com
    module Sign
      module Outs
        class CompletionsController < Side::Com::Sign::OutsController
          AUTHENTICATION_MODE = :open

          after_action :sign_out_notice_cache_headers!, only: :show

          def show
            complete
          end
        end
      end
    end
  end
end
