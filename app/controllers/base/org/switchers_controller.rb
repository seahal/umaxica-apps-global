# typed: false
# frozen_string_literal: true

module Base
  module Org
    class SwitchersController < Base::Org::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        authorize!(current_operator, to: :show?)
        render json: { status: "stub" }
      end

      def update
        authorize!(current_operator, to: :update?)
        render json: { status: "stub" }
      end
    end
  end
end
