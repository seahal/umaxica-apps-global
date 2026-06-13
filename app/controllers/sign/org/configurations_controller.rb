# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class ConfigurationsController < ::Sign::RedirectOnlyController
      AUTHENTICATION_MODE = :open

      def show
        redirect_to_acme_authority!("/configuration")
      end
    end
  end
end
