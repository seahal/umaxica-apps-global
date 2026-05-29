# typed: false
# frozen_string_literal: true

module Sign
  module App
    class ConfigurationsController < Sign::App::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_client! # FIXME: I don't think this is needed

      def show
      end
    end
  end
end
