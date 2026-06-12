# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class ConfigurationsController < ::Sign::Org::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_operator!

      def show
        render plain: "ok"
      end
    end
  end
end
