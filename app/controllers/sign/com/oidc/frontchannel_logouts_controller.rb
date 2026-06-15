# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Oidc
      class FrontchannelLogoutsController < ::Sign::Com::BareController
        include ::OidcRpLogoutReceiver

        def show
          handle_oidc_frontchannel_logout
        end
      end
    end
  end
end
