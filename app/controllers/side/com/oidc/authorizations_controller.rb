# typed: false
# frozen_string_literal: true

module Side
  module Com
    module Oidc
      class AuthorizationsController < Side::Com::ApplicationController
        AUTHENTICATION_MODE = :open

        skip_before_action :set_region, raise: false

        def show
          url = initiate_oidc_session!(screen_hint: "signup")
          redirect_to_oidc_authorization_url(url)
        end
      end
    end
  end
end
