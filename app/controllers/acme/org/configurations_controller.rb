# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class ConfigurationsController < Acme::Org::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        render json: { status: "ok" }
      end
    end
  end
end
