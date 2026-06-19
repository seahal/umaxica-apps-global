# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class SwitchersController < Acme::Org::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        render json: { status: "stub" }
      end

      def update
        render json: { status: "stub" }
      end
    end
  end
end
