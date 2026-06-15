# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Oidc
      class FrontchannelLogoutsController < ::Sign::App::BareController
        include ::OidcRpLogoutReceiver

        def show
          handle_oidc_frontchannel_logout
        end
      end
    end
  end
end
