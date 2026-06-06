# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class SelectorsController < Sign::Org::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_operator!

      def show
        redirect_to acme_org_selector_url(host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"))
      end
    end
  end
end
