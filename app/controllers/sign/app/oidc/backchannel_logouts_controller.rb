# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Oidc
      class BackchannelLogoutsController < ::Sign::App::BareController
        include ::OidcRpLogoutReceiver

        AUTHENTICATION_MODE = :bare

        protect_from_forgery with: :null_session

        def create
          handle_oidc_backchannel_logout
        end
      end
    end
  end
end
