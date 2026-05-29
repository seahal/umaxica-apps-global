# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class ConfigurationsController < Sign::Com::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_visitor! # FIXME: I don't think this is needed

      def show
      end
    end
  end
end
