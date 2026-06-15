# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Oidc
      class BackchannelLogoutsController < ::Sign::Org::BareController
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
