# typed: false
# frozen_string_literal: true

module Base
  module Com
    class SwitchersController < Base::Com::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        authorize!(current_visitor, to: :show?)
        render json: { status: "stub" }
      end

      def update
        authorize!(current_visitor, to: :update?)
        render json: { status: "stub" }
      end
    end
  end
end
