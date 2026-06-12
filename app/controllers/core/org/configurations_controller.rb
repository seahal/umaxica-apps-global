# typed: false
# frozen_string_literal: true

module Core
  module Org
    class ConfigurationsController < Core::Org::ApplicationController
      AUTHENTICATION_MODE = :private

      def show
        render template: "acme/org/roots/index"
      end
    end
  end
end
