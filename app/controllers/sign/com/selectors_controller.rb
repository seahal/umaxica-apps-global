# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class SelectorsController < Sign::Com::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_visitor!

      def show
        redirect_to(acme_com_selector_url(host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")))
      end
    end
  end
end
