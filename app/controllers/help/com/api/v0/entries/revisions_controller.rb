# typed: false
# frozen_string_literal: true

module Help
  module Com
    module Api
      module V0
        module Entries
          # Read-only revision reservation endpoint.
          class RevisionsController < Help::Com::BareController
            AUTHENTICATION_MODE = :bare

            def index
              render json: []
            end

            def show
              render json: {}
            end
          end
        end
      end
    end
  end
end
