# typed: false
# frozen_string_literal: true

module Core
  module Org
    module Api
      module V0
        module Token
          class RefreshesController < BaseController
            AUTHENTICATION_MODE = :bare

            def create
              refresh_core_browser_token!
            end
          end
        end
      end
    end
  end
end
