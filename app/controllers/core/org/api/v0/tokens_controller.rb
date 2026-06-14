# typed: false
# frozen_string_literal: true

module Core
  module Org
    module Api
      module V0
        class TokensController < BaseController
          AUTHENTICATION_MODE = :bare

          def refresh
            refresh_core_browser_token!
          end
        end
      end
    end
  end
end
