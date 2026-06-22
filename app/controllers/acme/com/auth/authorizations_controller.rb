# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Auth
      class AuthorizationsController < Acme::Com::ApplicationController
        AUTHENTICATION_MODE = :open

        skip_before_action :set_region, raise: false

        def show
          url = initiate_oidc_session!(screen_hint: screen_hint_param)
          redirect_to_oidc_authorization_url(url)
        end

        private

        def screen_hint_param
          return "signup" if params[:screen_hint].to_s == "signup"
          return "signin" if params[:screen_hint].to_s == "signin"

          nil
        end
      end
    end
  end
end
