# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class ConfigurationsController < PrivateController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_operator!

      def show
      end
    end
  end
end
