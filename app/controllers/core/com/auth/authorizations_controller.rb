# typed: false
# frozen_string_literal: true

module Core
  module Com
    module Auth
      class AuthorizationsController < Core::Com::ApplicationController
        AUTHENTICATION_MODE = :open

        skip_before_action :set_region, raise: false

        def show
          url = initiate_oidc_session!
          redirect_to_oidc_authorization_url(url)
        end
      end
    end
  end
end
