# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      module Mfa
        class ResetsController < PrivateController
          before_action :authenticate_client!

          def show
            head :not_implemented
          end

          def create
            head :not_implemented
          end
        end
      end
    end
  end
end
