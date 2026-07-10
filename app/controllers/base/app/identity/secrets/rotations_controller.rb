# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Secrets
        class RotationsController < BaseController
          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_client!
          def create
            authorize!(current_client, to: :update?)
            head :forbidden
          end
        end
      end
    end
  end
end
