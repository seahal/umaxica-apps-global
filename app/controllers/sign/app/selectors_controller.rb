# typed: false
# frozen_string_literal: true

module Sign
  module App
    class SelectorsController < Sign::App::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_client!

      def show
        redirect_to acme_app_selector_url(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"))
      end
    end
  end
end
