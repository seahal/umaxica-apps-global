# typed: false
# frozen_string_literal: true

module Base
  module Org
    class ConfigurationsController < Base::Org::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        render json: { status: "ok" }
      end
    end
  end
end
