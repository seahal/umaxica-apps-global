# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Secrets
        class RotationsController < BaseController
          before_action :authenticate_client!
          def create = head(:not_implemented)
        end
      end
    end
  end
end
