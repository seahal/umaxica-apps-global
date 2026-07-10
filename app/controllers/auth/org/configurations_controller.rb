# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class ConfigurationsController < ::Auth::RedirectOnlyController
      AUTHENTICATION_MODE = :open

      def show
        redirect_to_acme_authority!("/configuration")
      end
    end
  end
end
